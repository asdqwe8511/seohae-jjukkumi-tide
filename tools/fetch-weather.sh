#!/usr/bin/env bash
# 바다타임에서 앞바다 예보(기상청 원자료)를 다시 받아 index.html 의 WX 블록만 교체한다.
# 조석(TIDE) 데이터는 천문 계산이라 시즌 내내 유효하므로 건드리지 않는다.
#
# 사용법:  bash tools/fetch-weather.sh [index.html 경로]
# 실패하면 0이 아닌 코드로 끝나고 index.html 은 그대로 둔다.

set -uo pipefail

TARGET="${1:-index.html}"
CODES="608 151 150 466 370 1410 525 175 354 131 356 355 126 236 523 430"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

die(){ echo "중단: $*" >&2; exit 1; }

[ -f "$TARGET" ] || die "$TARGET 이 없다"
grep -q '/\* WX:START \*/' "$TARGET" || die "$TARGET 에 WX:START 마커가 없다"
grep -q '/\* WX:END \*/'   "$TARGET" || die "$TARGET 에 WX:END 마커가 없다"

# ---- 예보 표 파서: section1(그 항구가 속한 앞바다 구역)만 읽는다 -------------
parse_one(){   # $1 = 내려받은 html
  local f="$1" A B
  A=$(grep -n 'id="section1"' "$f" | head -1 | cut -d: -f1)
  B=$(grep -n 'id="section2"' "$f" | head -1 | cut -d: -f1)
  [ -n "$A" ] || return 1
  [ -n "$B" ] || B=$((A + 400))
  sed -n "${A},${B}p" "$f" | tr '\n' ' ' \
    | sed -E 's|<img[^>]*alt="([^"]*)"[^>]*>|\1@|g' > "$TMP/sec"

  # 첫 줄: 구역명
  grep -oE 'font-size: 16px[^>]*>[^<]+' "$TMP/sec" | head -1 | sed 's/.*>//' | tr -d ' \t'

  # 나머지: 셀들을 탭으로 이어 붙인 행
  sed 's|<tr|\n<tr|g' "$TMP/sec" | grep '<td' | while IFS= read -r row; do
    printf '%s\n' "$row" \
      | sed 's|</td>|\n|g' \
      | sed -E 's|<[^>]*>||g; s|&nbsp;| |g; s/^[[:space:]]+//; s/[[:space:]]+$//' \
      | tr '\n' '\t'
    echo
  done
}

# ---- 행 → JSON 조각 --------------------------------------------------------
ROWS_TO_JSON='
BEGIN{ FS="\t"; first=1; printf "{" }
FNR<=3 { next }
{
  if($1 ~ /^[0-9][0-9]\.[0-9][0-9]/){
    split($1,dd,"("); date=dd[1]; gsub(/\./,"-",date)
    yy = YEAR + ((CURMON=="12" && substr(date,1,2)=="01") ? 1 : 0)   # 연말에 해를 넘길 때
    date = yy "-" date
    if($2=="오전"){ emit(date,"am",$3,$4,$5,$6) } else { emit(date,"all",$2,$3,$4,$5) }
  } else if($1=="오후"){ emit(date,"pm",$2,$3,$4,$5) }
}
function emit(d,part,sky,wd,ws,wv,   s){
  s=sky; sub(/@.*/,"",s)
  gsub(/"/,"",s); gsub(/"/,"",wd); gsub(/"/,"",ws); gsub(/"/,"",wv)
  printf "%s\"%s|%s\":{\"s\":\"%s\",\"wd\":\"%s\",\"ws\":\"%s\",\"wv\":\"%s\"}", (first?"":","), d, part, s, wd, ws, wv
  first=0
}
END{ printf "}" }
'

TODAY_KST=$(TZ=Asia/Seoul date +%F)
YEAR=$(TZ=Asia/Seoul date +%Y)
CURMON=$(TZ=Asia/Seoul date +%m)

echo "수집 시작 ($TODAY_KST KST)"
for c in $CODES; do
  curl -sS --fail --max-time 30 --retry 2 --retry-delay 3 \
       "https://www.badatime.com/${c}/sea-cast" -o "$TMP/${c}.html" \
    || die "항구 $c 내려받기 실패"
  parse_one "$TMP/${c}.html" > "$TMP/${c}.tsv" || die "항구 $c 파싱 실패"
  zone=$(head -1 "$TMP/${c}.tsv")
  rows=$(($(wc -l < "$TMP/${c}.tsv") - 3))
  [ -n "$zone" ] || die "항구 $c 의 예보구역명을 못 읽었다"
  [ "$rows" -ge 5 ] || die "항구 $c 의 예보 행이 $rows 개뿐이다"
  echo "  $c  $zone  ${rows}행"
done

# ---- 구역별로 합쳐 JSON 조립 ------------------------------------------------
ZONES=$(for c in $CODES; do head -1 "$TMP/${c}.tsv"; done | sort -u)
nz=$(printf '%s\n' "$ZONES" | wc -l)
[ "$nz" -ge 3 ] || die "예보구역이 ${nz}개뿐이다 (보통 5개)"

{
  printf '{"stamp":"%s","zones":{' "$TODAY_KST"
  fz=1
  for z in $ZONES; do
    rep=""
    for c in $CODES; do [ "$(head -1 "$TMP/${c}.tsv")" = "$z" ] && { rep="$c"; break; }; done
    [ $fz -eq 1 ] || printf ','
    fz=0
    printf '"%s":' "$z"
    awk -v YEAR="$YEAR" -v CURMON="$CURMON" "$ROWS_TO_JSON" "$TMP/${rep}.tsv"
  done
  printf '},"portZone":{'
  fp=1
  for c in $CODES; do
    [ $fp -eq 1 ] || printf ','
    fp=0
    printf '"%s":"%s"' "$c" "$(head -1 "$TMP/${c}.tsv")"
  done
  printf '}}'
} > "$TMP/wx.json"

entries=$(grep -o '"20[0-9][0-9]-' "$TMP/wx.json" | wc -l)
[ "$entries" -ge 25 ] || die "예보 항목이 ${entries}개뿐이다"
echo "구역 ${nz}개 · 예보 ${entries}건 수집"

# ---- index.html 의 WX 블록 교체 --------------------------------------------
awk -v jsonfile="$TMP/wx.json" '
  /\/\* WX:START \*\// {
    print
    printf "const WX ="
    while((getline line < jsonfile) > 0) printf "%s", line
    printf ";\n"
    skip=1
    next
  }
  /\/\* WX:END \*\// { skip=0 }
  !skip { print }
' "$TARGET" > "$TMP/out.html" || die "치환 실패"

# 치환 결과 검증: 나머지 구조가 살아 있는지
for needle in 'const TIDE' 'const WX' '/* WX:START */' '/* WX:END */' '</html>'; do
  grep -qF "$needle" "$TMP/out.html" || die "치환 결과에 '$needle' 이 없다"
done
old=$(wc -c < "$TARGET"); new=$(wc -c < "$TMP/out.html")
[ "$new" -gt $((old * 8 / 10)) ] || die "결과 파일이 너무 작다 ($old → $new 바이트)"

mv "$TMP/out.html" "$TARGET"
echo "완료: $TARGET 갱신 ($old → $new 바이트)"
