# spring-backend-challenge

매일 하나씩 스프링 실무 과제를 풀어보는 프로젝트입니다.
과제 하나가 `challenges/` 아래의 독립된 Spring Boot 앱(모듈) 하나로 구성된다.

## 새 과제 만드는 스크립트

`new-challenge.sh` 스크립트를 작성했다.

```bash
./new-challenge.sh <번호> <이름>

# 예
./new-challenge.sh 002 order
```

- 번호는 세 자리(`002`), 이름은 영어 소문자·숫자·`-`만 (`point-system`)
- 폴더, 패키지, 메인 클래스, DB schema, 서버 포트, README를 자동으로 생성한다.
- 만든 뒤 IntelliJ에서 Gradle 새로고침

## 이전 과제 확장하기

이전 과제의 코드를 복사해서 새 과제로 시작할 때.

```bash
./new-challenge.sh <번호> <이름> --from <이전 과제 폴더명>

# 예
./new-challenge.sh 004 workshop-advanced --from 001-workshop
```

## 과제 목록

| #   | 주제   | 시리즈 | 기반 | 키워드 |
|-----|--------|--------|------|--------|
| 001 | [워크샵](challenges/001-workshop) | - | - | |
