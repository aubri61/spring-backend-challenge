#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# 새 과제 모듈 만들기
#
#   ./new-challenge.sh <번호> <이름>                      빈 과제 새로 만들기
#   ./new-challenge.sh <번호> <이름> --from <기존 과제>    기존 과제를 복사해서 확장하기
#
# 예)
#   ./new-challenge.sh 002 order
#   ./new-challenge.sh 004 coupon-concurrency --from 001-coupon
#
# 하는 일
#   - challenges/<번호>-<이름>/ 폴더, build.gradle, 메인/테스트 클래스, application.yml, README 생성
#   - 패키지: dev.aubri.<이름에서 - 뺀 것>   (point-system -> dev.aubri.pointsystem)
#   - DB schema: <이름의 - 를 _ 로>          (point-system -> point_system)
#   - 서버 포트: 8080 + 번호                  (002 -> 8082)
#   - 루트 README 과제 목록 표에 한 줄 추가
# ─────────────────────────────────────────────────────────────
set -euo pipefail

usage() {
  sed -n '3,10p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
}

[ $# -ge 2 ] || usage
NUM="$1"; NAME="$2"; shift 2
FROM=""
if [ $# -gt 0 ]; then
  if [ "$1" = "--from" ] && [ $# -eq 2 ]; then FROM="$2"; else usage; fi
fi

[[ "$NUM" =~ ^[0-9]{3}$ ]]          || { echo "❌ 번호는 세 자리 숫자로 써주세요 (예: 002)"; exit 1; }
[[ "$NAME" =~ ^[a-z][a-z0-9-]*$ ]]  || { echo "❌ 이름은 영어 소문자, 숫자, - 만 쓸 수 있어요 (예: point-system)"; exit 1; }

ROOT="$(cd "$(dirname "$0")" && pwd)"
CH="$ROOT/challenges"
MODULE="$NUM-$NAME"
DIR="$CH/$MODULE"

EXISTING="$(find "$CH" -mindepth 1 -maxdepth 2 -type d -name "$NUM-*" | head -1)"
[ -z "$EXISTING" ] || { echo "❌ 이미 $NUM 번 과제가 있어요: ${EXISTING#$ROOT/}"; exit 1; }

PKG="${NAME//-/}"
BASE_PKG="dev.aubri.$PKG"
SCHEMA="${NAME//-/_}"
CLASS="$(echo "$NAME" | awk -F- '{for(i=1;i<=NF;i++) printf "%s%s", toupper(substr($i,1,1)), substr($i,2)}')Application"
PORT=$((8080 + 10#$NUM))
TODAY="$(date +%Y-%m-%d)"
PKG_PATH="${BASE_PKG//.//}"

write_readme() {   # $1 = 기반 표시
  cat > "$DIR/README.md" <<EOF
# $NUM. $NAME

> 기반: $1 · 시작일: $TODAY

## 요구사항
-

## 제약조건
-

## 설계
### ERD

### API
| Method | URI | 설명 |
|--------|-----|------|
|        |     |      |

## 핵심 고민과 선택
- **고민:**
  - **선택:**
  - **이유:**

## 회고
- 잘한 점:
- 아쉬운 점 / 다음에 개선할 점:

## 실행
\`\`\`bash
docker compose up -d
./gradlew :$MODULE:bootRun
./gradlew :$MODULE:test
\`\`\`
EOF
}

if [ -z "$FROM" ]; then
  # ───── 빈 과제 새로 만들기 ─────
  mkdir -p "$DIR/src/main/java/$PKG_PATH" "$DIR/src/test/java/$PKG_PATH" "$DIR/src/main/resources/db/migration"
  touch "$DIR/src/main/resources/db/migration/.gitkeep"

  cat > "$DIR/build.gradle" <<'EOF'
plugins {
    id 'challenge.spring-boot-app'
}

// 이 과제에만 필요한 의존성을 추가한다.
dependencies {
    // implementation 'org.springframework.boot:spring-boot-starter-security'
    // testImplementation 'org.springframework.boot:spring-boot-starter-security-test'
}
EOF

  cat > "$DIR/src/main/resources/application.yml" <<EOF
spring:
  application:
    name: $NAME

  # DB 는 루트 compose.yml 의 postgres 하나를 같이 쓰고, 과제마다 schema 로 분리한다.
  datasource:
    url: jdbc:postgresql://localhost:15440/backend_challenge?currentSchema=$SCHEMA
    username: \${DB_USERNAME:challenge}
    password: \${DB_PASSWORD:letsrock}

  jpa:
    hibernate:
      ddl-auto: validate
    open-in-view: false

  flyway:
    enabled: true
    schemas: $SCHEMA   # 없으면 flyway 가 만들어 준다

server:
  port: $PORT
EOF

  cat > "$DIR/src/main/java/$PKG_PATH/$CLASS.java" <<EOF
package $BASE_PKG;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class $CLASS {

	public static void main(String[] args) {
		SpringApplication.run($CLASS.class, args);
	}

}
EOF

  cat > "$DIR/src/test/java/$PKG_PATH/TestcontainersConfiguration.java" <<EOF
package $BASE_PKG;

import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.annotation.Bean;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

@TestConfiguration(proxyBeanMethods = false)
class TestcontainersConfiguration {

	@Bean
	@ServiceConnection
	PostgreSQLContainer postgresContainer() {
		return new PostgreSQLContainer(DockerImageName.parse("postgres:17"));
	}

}
EOF

  cat > "$DIR/src/test/java/$PKG_PATH/${CLASS}Tests.java" <<EOF
package $BASE_PKG;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;

@Import(TestcontainersConfiguration.class)
@SpringBootTest
class ${CLASS}Tests {

	@Test
	void contextLoads() {
	}

}
EOF

  cat > "$DIR/src/test/java/$PKG_PATH/Test$CLASS.java" <<EOF
package $BASE_PKG;

import org.springframework.boot.SpringApplication;

public class Test$CLASS {

	public static void main(String[] args) {
		SpringApplication.from($CLASS::main).with(TestcontainersConfiguration.class).run(args);
	}

}
EOF

  write_readme "-"
  BASED="-"
else
  # ───── 기존 과제 복사해서 확장하기 ─────
  SRC="$(find "$CH" -mindepth 1 -maxdepth 2 -type d -name "$FROM" | head -1)"
  [ -n "$SRC" ] || { echo "❌ '$FROM' 과제를 못 찾았어요. challenges/ 아래 폴더 이름을 그대로 써주세요."; exit 1; }

  MAIN_FILE="$(grep -rl '@SpringBootApplication' "$SRC/src/main/java" | head -1)"
  [ -n "$MAIN_FILE" ] || { echo "❌ $FROM 에서 @SpringBootApplication 클래스를 못 찾았어요."; exit 1; }
  OLD_CLASS="$(basename "$MAIN_FILE" .java)"
  OLD_PKG="$(sed -n 's/^package \(.*\);/\1/p' "$MAIN_FILE" | head -1)"
  OLD_PKG_PATH="${OLD_PKG//.//}"
  OLD_YML="$SRC/src/main/resources/application.yml"
  OLD_SCHEMA="$(sed -n 's/.*currentSchema=\([A-Za-z0-9_]*\).*/\1/p' "$OLD_YML" | head -1)"
  OLD_NAME="${FROM#*-}"

  rsync -a --exclude build --exclude .gradle --exclude out "$SRC/" "$DIR/"

  # 패키지 폴더 옮기기 (main, test)
  for kind in main test; do
    from_dir="$DIR/src/$kind/java/$OLD_PKG_PATH"
    to_dir="$DIR/src/$kind/java/$PKG_PATH"
    if [ -d "$from_dir" ] && [ "$from_dir" != "$to_dir" ]; then
      mkdir -p "$to_dir"
      mv "$from_dir"/* "$to_dir"/
      rmdir "$from_dir" 2>/dev/null || true
      # 비어버린 상위 폴더 정리
      parent="$(dirname "$from_dir")"
      while [ "$parent" != "$DIR/src/$kind/java" ] && rmdir "$parent" 2>/dev/null; do parent="$(dirname "$parent")"; done
    fi
  done

  # 클래스 파일 이름 바꾸기 (WorkshopApplication -> OrderApplication 등)
  find "$DIR/src" -name "*$OLD_CLASS*.java" | while read -r f; do
    mv "$f" "$(dirname "$f")/$(basename "$f" | sed "s/$OLD_CLASS/$CLASS/")"
  done

  # 파일 내용 바꾸기: 패키지, 클래스 이름, schema, 포트, 앱 이름
  find "$DIR" -type f \( -name '*.java' -o -name '*.yml' -o -name '*.yaml' -o -name '*.properties' -o -name '*.gradle' \) -print0 \
    | xargs -0 perl -pi -e "
        s/\Q$OLD_PKG\E\b/$BASE_PKG/g;
        s/\b(Test)?\Q$OLD_CLASS\E/\$1$CLASS/g;
        s/currentSchema=\Q$OLD_SCHEMA\E\b/currentSchema=$SCHEMA/g;
        s/^(\s*schemas:\s*)\Q$OLD_SCHEMA\E\b/\${1}$SCHEMA/;
        s/^(\s*port:\s*)\d+/\${1}$PORT/;
        s/^(\s*name:\s*)\Q$OLD_NAME\E\s*\$/\${1}$NAME\n/;
      "

  write_readme "[$FROM](${SRC#$ROOT/challenges/}) 에서 확장"
  # README 의 기반 링크를 상대 경로로
  REL_SRC="$(python3 -c "import os,sys;print(os.path.relpath(sys.argv[1],sys.argv[2]))" "$SRC" "$DIR" 2>/dev/null || echo "../$FROM")"
  perl -pi -e "s|\Q[$FROM](\E[^)]*\)|[$FROM]($REL_SRC)|" "$DIR/README.md"
  BASED="${FROM%%-*}"
fi

# 루트 README 과제 목록에 한 줄 추가
ROW="| $NUM | [$NAME](${DIR#$ROOT/}) | - | $BASED | |"
if [ -f "$ROOT/README.md" ]; then
  LAST="$(grep -n '^| [0-9][0-9][0-9] ' "$ROOT/README.md" | tail -1 | cut -d: -f1 || true)"
  if [ -n "$LAST" ]; then
    awk -v n="$LAST" -v row="$ROW" '{print} NR==n{print row}' "$ROOT/README.md" > "$ROOT/README.md.tmp" && mv "$ROOT/README.md.tmp" "$ROOT/README.md"
  fi
fi

cat <<EOF

✅ ${DIR#$ROOT/} 만들었어요
   패키지   $BASE_PKG
   메인     $CLASS
   schema   $SCHEMA
   포트     $PORT
EOF
[ -z "$FROM" ] || echo "   기반     $FROM 복사"
cat <<EOF

다음 할 일
  1. IntelliJ 에서 Gradle 새로고침 (오른쪽 코끼리 → 🔄)
  2. 실행:  ./gradlew :$MODULE:bootRun   (또는 $CLASS 의 ▶ 버튼)
EOF
