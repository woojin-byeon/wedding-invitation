# woojin-world

DevOps / 인프라 엔지니어 개인 포트폴리오 사이트. 외부 CDN·프레임워크 의존성이 전혀 없는 순수 HTML/CSS/JS 정적 사이트라서, 폐쇄망이나 프록시 뒤에서도 그대로 동작합니다.

```
woojin-world/
├── index.html                  # 페이지 본문 (여기만 고쳐도 대부분 커버됨)
├── assets/
│   ├── css/main.css            # 테마·레이아웃
│   ├── js/main.js              # 부팅 시퀀스, 타이핑, 스크롤 애니메이션
│   └── img/                    # (선택) 프로필 사진 등
└── deploy/
    ├── woojin-world.conf       # nginx server block
    └── deploy.sh               # 배포 + 검증 스크립트
```

## 배포

```bash
# 1) 서버로 전송
scp -r woojin-world rocky@woojin-world.duckdns.org:~/

# 2) 배포 실행
cd ~/woojin-world/deploy
chmod +x deploy.sh
sudo ./deploy.sh
```

`deploy.sh`가 하는 일: 기존 사이트 tar 백업 → `/srv/woojin-world`로 rsync → 퍼미션/SELinux 컨텍스트 정리 → nginx conf 배치 → `nginx -t` 문법 검증 → reload → firewalld 포트 개방 → `/health` 200 확인.

## TLS 인증서 (최초 1회)

DuckDNS 도메인이 이미 서버 공인 IP를 가리키고 있어야 합니다.

```bash
sudo dnf install -y certbot python3-certbot-nginx
sudo mkdir -p /var/www/letsencrypt

sudo certbot certonly --webroot \
  -w /var/www/letsencrypt \
  -d woojin-world.duckdns.org \
  --agree-tos -m YOUR_EMAIL@example.com --no-eff-email

sudo systemctl enable --now certbot-renew.timer
```

이걸 붙이면 브라우저의 "연결이 안전하지 않음" 경고가 사라집니다. (self-signed 인증서는 CA 체인이 없어서 계속 경고가 뜹니다.)

## 반드시 바꿔야 할 곳

`index.html`에서 아래 플레이스홀더를 실제 값으로 교체하세요.

| 위치 | 플레이스홀더 |
|---|---|
| contact 섹션 · 하단 버튼 | `YOUR_EMAIL@example.com` |
| contact 섹션 | `github.com/YOUR_ID` |
| hero 통계 | `data-count` 값 (경력 연차 등) |
| about / projects | 실제 수치·성과로 보강 |

## 커스터마이징

- **색상**: `assets/css/main.css` 최상단 `:root` 변수만 바꾸면 전체 테마가 바뀝니다. (`--acc`가 메인 포인트 컬러)
- **부팅 로그 문구**: `assets/js/main.js`의 `BOOT` 배열
- **타이핑 문구**: 같은 파일의 `ROLES` 배열
- **아키텍처 다이어그램**: `index.html`의 인라인 SVG — 좌표만 손대면 노드 추가 가능

## 로컬 확인

```bash
cd woojin-world
python3 -m http.server 8080
# http://localhost:8080
```

## 이스터에그

키보드로 ↑↑↓↓←→←→BA 입력.
