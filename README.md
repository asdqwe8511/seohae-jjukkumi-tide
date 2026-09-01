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
