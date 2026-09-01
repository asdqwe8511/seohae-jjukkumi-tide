# 서해 쭈꾸미 물때 — 배포용

`index.html` 하나로 끝나는 정적 사이트다. 빌드 과정도, 서버도, 외부 API 호출도 없다.
물때·바다날씨 데이터가 파일 안에 들어 있고, 바깥으로 나가는 요청은 Google Fonts뿐이다.

## 올리는 법

### Netlify Drop — 가장 빠름
1. https://app.netlify.com/drop 접속
2. 이 `public` 폴더를 통째로 드래그해서 놓기
3. 바로 `https://<임의이름>.netlify.app` 주소가 나온다. 계정을 만들면 주소를 고정하고 도메인도 붙일 수 있다.

### GitHub Pages — 주소를 계속 유지할 때
```bash
cd public
git init -b main
git add index.html
git commit -m "서해 쭈꾸미 물때"
git remote add origin https://github.com/<계정>/<저장소>.git
git push -u origin main
```
저장소 Settings → Pages → Source를 `main` 브랜치 루트로 지정하면
`https://<계정>.github.io/<저장소>/` 로 열린다.

### Cloudflare Pages / Vercel
둘 다 "정적 파일 직접 업로드" 항목에서 이 폴더를 올리면 끝난다.

## 고칠 만한 것

- **바다날씨는 2026-09-01 기준 8일치 스냅샷**이다. 조석(물때)은 천문 계산이라 11월 30일까지 정확하지만,
  날씨는 시간이 지나면 낡는다. 갱신하려면 페이지 안 `const WX = {...}` 블록을 새 예보로 교체하면 된다.
- 조석 데이터는 `const TIDE = {...}` 블록에 항구 코드별로 들어 있다. 2026년 9~11월만 담겨 있다.
- 출조지를 늘리거나 줄이려면 `ORDER` 배열과 `GROUPS` 목록을 함께 고친다.

## 출처

- 조석예보·앞바다 예보: 바다타임(https://www.badatime.com), 원자료는 국립해양조사원과 기상청
- 출항 통제 기준: 어선안전조업법, 낚시 관리 및 육성법

## 자동 갱신

`.github/workflows/update-weather.yml` 이 **매주 월요일 06:00 KST**에 돌면서
`tools/fetch-weather.sh` 로 앞바다 예보를 다시 받아 `index.html` 의 `WX` 블록만 교체한다.
예보가 8일치라 주 1회면 빈틈이 생기지 않는다. 변화가 없으면 커밋하지 않는다.

- 수동 실행: 저장소 Actions 탭 → "바다날씨 주간 갱신" → Run workflow
- 로컬 실행: `bash tools/fetch-weather.sh index.html`
- 스크립트는 수집 실패·파싱 이상·결과 파일 축소를 감지하면 중단하고 `index.html` 을 건드리지 않는다.

조석(`TIDE`) 데이터는 자동 갱신 대상이 아니다. 천문 계산이라 2026-11-30까지 이미 정확하다.

## OG 이미지

`og.png` (1200×630)는 링크 공유용 미리보기 이미지다. `tools/make-og-image.ps1` 이 .NET System.Drawing으로
사이트와 같은 팔레트·서체로 그린다. 사이트 데이터가 바뀌어도 이 이미지는 자동 갱신되지 않는다 — 필요할 때만 다시 만든다.

실행하려면 먼저 폰트 TTF를 `tools/fonts/` 에 받아야 한다. Google Fonts는 UA에 따라 포맷을 달리 주므로
구형 안드로이드 UA로 요청해야 TTF가 온다.

```bash
UA="Mozilla/5.0 (Linux; U; Android 2.2; en-us; Nexus One Build/FRF91) AppleWebKit/533.1"
# Hahmlet:800 -> Hahmlet-800.ttf, IBM+Plex+Sans+KR:400 -> PlexKR-400.ttf,
# IBM+Plex+Sans+KR:500 -> PlexKR-500.ttf, IBM+Plex+Mono:500 -> PlexMono-500.ttf
curl -s -A "$UA" "https://fonts.googleapis.com/css?family=Hahmlet:800&subset=korean" # 여기서 나온 .ttf URL을 받는다
```

그다음 `powershell -File tools/make-og-image.ps1 og.png`.
스크립트는 UTF-8 BOM으로 저장돼 있어야 한다 (PowerShell 5.1이 BOM 없는 파일을 ANSI로 읽어 한글이 깨진다).
