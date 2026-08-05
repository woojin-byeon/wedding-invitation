# woojin-world

자기 상태를 스스로 말하는 개인 웹서버.

첫 화면 상단의 uptime · load · 메모리 · 응답 횟수는 전부 그 서버에서 실시간으로
읽어온 값이다. **하드코딩된 숫자는 하나도 없고, 읽어올 수 없는 값은 가짜로 채우는
대신 항목 자체를 숨긴다.** 이 원칙이 이 사이트의 유일한 무기다.

---

## 구성

```
                     브라우저
                        │
                        ▼
              ┌───────────────────┐
              │      nginx        │  정적 파일 + /api/ 프록시
              └───────────────────┘
                        │ 127.0.0.1:8099
                        ▼
              ┌───────────────────┐
              │  status_api.py    │  표준 라이브러리만 사용
              └───────────────────┘
                        │
                 /proc · /etc/os-release · git
```

```
woojin-world/
├── deploy.sh                    설치·배포·점검 (멱등)
├── api/status_api.py            상태 API (의존성 0)
├── nginx/woojin-world.conf      nginx 사이트 설정
├── systemd/woojin-status.service systemd 유닛 (하드닝 포함)
├── test/local_gateway.py        로컬 검증용 nginx 흉내
└── site/
    ├── index.html               랜딩
    ├── 404.html
    ├── build/                   만든 것들
    ├── now/                     요즘 (성숙도별 노트)
    ├── incidents/               부서진 것들 ← 이 사이트의 핵심
    │   ├── curl-uppercase-proxy/
    │   └── http-server-blocking/
    └── assets/                  style.css, main.js
```

---

## 설치

서버 A(Rocky Linux 8.10)에 이 디렉터리를 통째로 올린 뒤:

```bash
sudo dnf install -y nginx python3 git
sudo ./deploy.sh install
```

`install`이 하는 일:

1. `/srv/woojin-world/` 에 파일 배치
2. systemd 유닛 등록 후 기동
3. SELinux가 Enforcing이면 `httpd_can_network_connect` 및 컨텐츠 레이블 적용
4. nginx 설정 배치 → `nginx -t` 통과 시에만 reload (실패 시 자동 롤백)
5. 애플리케이션 계층 헬스체크로 검증

사이트만 갱신할 때:

```bash
sudo ./deploy.sh update
sudo ./deploy.sh verify
```

---

## 배포 전에 반드시 바꿀 것

`CHANGE-ME`로 표시된 곳과 `<!-- TODO -->` 주석을 전부 채워야 한다.

| 위치 | 내용 |
|---|---|
| `site/index.html` | GitHub 주소, 메일 주소 |
| `site/build/index.html` | 저장소 링크 |
| `site/now/index.html` | 지금 하는 일 / 막혀 있는 것 |
| `site/incidents/*/index.html` | 실제 로그·근거 (`<!-- TODO -->` 위치) |
| `nginx/woojin-world.conf` | `server_name` |
| `systemd/woojin-status.service` | `Documentation=` URL |

**사내 정보 점검** — 커밋 전 반드시:

```bash
grep -rEn '172\.1[0-9]\.|10\.[0-9]+\.|kblife|wok-01' site/ || echo "clean"
```

문서의 IP는 전부 문서화 전용 대역(`192.0.2.0/24`, `10.0.0.10`)으로 바꿔 두었다.
실제 사내 IP·호스트명이 git 히스토리에 한 번 들어가면 되돌리기 어렵다.

---

## 로컬에서 미리 보기

서버 없이 확인할 수 있다.

```bash
python3 api/status_api.py &          # 상태 API
python3 test/local_gateway.py        # nginx 흉내 (127.0.0.1:8080)
```

`test/local_gateway.py`는 검증 전용이다. 실제 서비스에 쓰지 않는다 —
그 이유는 [/incidents/http-server-blocking](site/incidents/http-server-blocking/)에 적어 두었다.

---

## 설계 판단

**카운터를 메모리에 두고 주기적으로만 디스크에 내린다.**
요청마다 `fsync`를 호출하면 응답 시간이 디스크 지연에 묶인다. 실측으로
요청당 12–115ms → 0.22ms로 떨어졌다. 대가는 급작스러운 종료 시 최대 10건 유실이고,
개인 사이트 카운터에는 받아들일 만한 트레이드오프다. 정상 종료(`SIGTERM`)에서는
잔여분을 반드시 플러시하므로 systemd restart로는 유실되지 않는다.

**`git`·`nginx -v` 같은 서브프로세스 호출은 30초 TTL로 캐시한다.**
배포는 자주 일어나지 않는데 매 요청마다 프로세스를 띄우는 것은 낭비다.

**상태 API는 `127.0.0.1`에만 바인딩한다.**
외부 노출 경로는 nginx의 `location /api/` 하나뿐이고, 여기에만 rate limit을 건다.

**systemd 유닛을 강하게 잠갔다.**
이 프로세스가 하는 일은 파일을 읽고 숫자를 세는 것뿐이므로
`DynamicUser` · `ProtectSystem=strict` · `SystemCallFilter` · `IPAddressDeny=any`로
권한을 최대한 뺏었다. `DynamicUser`는 git이 "dubious ownership"으로 거부하게 만드는데,
설정 파일 대신 `GIT_CONFIG_*` 환경변수로 `safe.directory`를 주입해 해결했다.

**API가 죽어도 페이지는 뜬다.**
`proxy_read_timeout 3s`로 짧게 끊고, 프론트엔드는 실패 시 안내 문구로 대체한다.
검증 완료: 상태 API를 내려도 모든 페이지가 `HTTP 200`.

---

## 검증 결과

| 항목 | 결과 |
|---|---|
| 전 페이지 응답 | `HTTP 200`, 평균 0.7ms |
| HTML 중첩 구조 | 6개 파일 전부 통과 |
| `/build` → `/build/` | `301` 정상 |
| 상태 API 지연 | 0.22ms (warm) |
| 200 병렬 요청 카운터 정합성 | 유실 0건 |
| `SIGTERM` 시 카운터 플러시 | 정확히 일치 |
| 상태 API 다운 시 페이지 | `HTTP 200` 유지 |
| null 값 처리 | 항목 숨김 (0/undefined 노출 없음) |

---

## 다음

- [ ] 이 서버 구성을 Ansible role로 역이관 — 손으로 한 건 재현되지 않는다
- [ ] GitHub Actions에서 `ansible-lint` + 멱등성 검사
- [ ] 랜딩만 GitHub Pages로 분리 (서버가 죽어도 URL은 살아 있도록)
- [ ] 모니터링 노드를 이 호스트 밖으로 분리 (지금은 감시자와 대상이 같은 기계)
