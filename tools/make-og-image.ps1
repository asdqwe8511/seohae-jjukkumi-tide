Add-Type -AssemblyName System.Drawing

$here    = Split-Path -Parent $MyInvocation.MyCommand.Path
$fontDir = Join-Path $here "fonts"
$outPath = $args[0]
if (-not $outPath) { $outPath = Join-Path $here "og.png" }

# ---- 폰트 적재 -------------------------------------------------------------
$pfc = New-Object System.Drawing.Text.PrivateFontCollection
foreach ($f in @("Hahmlet-800.ttf","PlexKR-400.ttf","PlexKR-500.ttf","PlexMono-500.ttf")) {
  $p = Join-Path $fontDir $f
  if (-not (Test-Path $p)) { throw "폰트 없음: $p" }
  $pfc.AddFontFile($p)
}
$fam = @{}
foreach ($ff in $pfc.Families) { $fam[$ff.Name] = $ff }
Write-Output ("적재된 폰트: " + ($fam.Keys -join ", "))

function Get-Family([string]$name) {
  if ($fam.ContainsKey($name)) { return $fam[$name] }
  foreach ($k in $fam.Keys) { if ($k -like "*$name*") { return $fam[$k] } }
  throw "폰트 계열을 못 찾음: $name"
}

$famTitle = Get-Family "Hahmlet"
$famSans  = Get-Family "IBM Plex Sans KR"
$famMono  = Get-Family "IBM Plex Mono"

function New-Px([System.Drawing.FontFamily]$family, [single]$px, [System.Drawing.FontStyle]$style) {
  New-Object System.Drawing.Font($family, $px, $style, [System.Drawing.GraphicsUnit]::Pixel)
}

# ---- 색 --------------------------------------------------------------------
function C([string]$hex, [int]$a = 255) {
  $r = [Convert]::ToInt32($hex.Substring(1,2),16)
  $g = [Convert]::ToInt32($hex.Substring(3,2),16)
  $b = [Convert]::ToInt32($hex.Substring(5,2),16)
  [System.Drawing.Color]::FromArgb($a,$r,$g,$b)
}
$cBg    = C "#08110F"
$cInk   = C "#E7F1EE"
$cInk2  = C "#A8BEB8"
$cInk3  = C "#758C86"
$cSea   = C "#57C6B5"
$cOchre = C "#E0AE5A"
$cLine  = C "#1D332F"
$cChip  = C "#28453F"

# ---- 캔버스 ----------------------------------------------------------------
$W = 1200; $H = 630; $M = 76
$bmp = New-Object System.Drawing.Bitmap($W, $H, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g   = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.Clear($cBg)

$sf = [System.Drawing.StringFormat]::GenericTypographic.Clone()
$sf.FormatFlags = $sf.FormatFlags -bor [System.Drawing.StringFormatFlags]::NoWrap

# 기준선(baseline) 기준으로 그린다
function Draw-Base([string]$text, [System.Drawing.Font]$font, [System.Drawing.Color]$color, [single]$x, [single]$baseline) {
  $ff = $font.FontFamily
  $asc = $ff.GetCellAscent($font.Style) / $ff.GetEmHeight($font.Style) * $font.Size
  $br = New-Object System.Drawing.SolidBrush($color)
  $g.DrawString($text, $font, $br, $x, ($baseline - $asc), $sf)
  $br.Dispose()
}
function Get-TextWidth([string]$text, [System.Drawing.Font]$font) {
  return $g.MeasureString($text, $font, [System.Drawing.PointF]::new(0,0), $sf).Width
}
function Draw-BaseRight([string]$text, [System.Drawing.Font]$font, [System.Drawing.Color]$color, [single]$right, [single]$baseline) {
  Draw-Base $text $font $color ($right - (Get-TextWidth $text $font)) $baseline
}
# 자간을 벌려 한 글자씩
function Draw-Tracked([string]$text, [System.Drawing.Font]$font, [System.Drawing.Color]$color, [single]$x, [single]$baseline, [single]$track) {
  $cx = $x
  foreach ($ch in $text.ToCharArray()) {
    $s = [string]$ch
    Draw-Base $s $font $color $cx $baseline
    $cx += (Get-TextWidth $s $font) + $track
  }
}

# ---- 조석 곡선 -------------------------------------------------------------
$EX = @(
  @(0.28,86), @(5.55,732), @(12.58,80), @(17.93,727),
  @(24.87,118), @(30.08,707), @(37.08,95), @(42.58,713), @(49.2,120)
)
function H-At([double]$t) {
  if ($t -le $EX[0][0]) { return $EX[0][1] }
  if ($t -ge $EX[$EX.Count-1][0]) { return $EX[$EX.Count-1][1] }
  $i = 0
  while ($i -lt $EX.Count-2 -and $EX[$i+1][0] -lt $t) { $i++ }
  $t1 = $EX[$i][0]; $h1 = $EX[$i][1]; $t2 = $EX[$i+1][0]; $h2 = $EX[$i+1][1]
  $p = ($t - $t1) / ($t2 - $t1)
  return ($h1+$h2)/2 + ($h1-$h2)/2 * [Math]::Cos([Math]::PI*$p)
}
$CT = 402.0; $CB = 606.0; $T0 = 0.0; $T1 = 48.0; $yMax = 820.0
function XT([double]$t) { return [single](($t - $T0) / ($T1 - $T0) * $W) }
function YH([double]$h) { return [single]($CB - ($CB - $CT) * ($h / $yMax)) }

# 수평 격자
$penLine = New-Object System.Drawing.Pen($cLine, 1)
foreach ($gv in @(0,200,400,600,800)) {
  $y = YH $gv
  $g.DrawLine($penLine, [single]0, $y, [single]$W, $y)
}
$penLine.Dispose()

# 곡선 점 모으기
$pts = New-Object System.Collections.Generic.List[System.Drawing.PointF]
for ($x = 0; $x -le $W; $x += 3) {
  $t = $T0 + ($x / $W) * ($T1 - $T0)
  $pts.Add((New-Object System.Drawing.PointF([single]$x, (YH (H-At $t)))))
}
$curve = $pts.ToArray()

# 면 채우기 (세로 그라데이션)
$poly = New-Object System.Collections.Generic.List[System.Drawing.PointF]
$poly.AddRange($curve)
$poly.Add((New-Object System.Drawing.PointF([single]$W, [single]$H)))
$poly.Add((New-Object System.Drawing.PointF([single]0,  [single]$H)))
$rect = New-Object System.Drawing.RectangleF(0, [single]$CT, [single]$W, [single]($H - $CT))
$lgb  = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, (C "#57C6B5" 82), (C "#57C6B5" 5), 90.0)
$blend = New-Object System.Drawing.Drawing2D.ColorBlend(3)
$blend.Colors    = @((C "#57C6B5" 82), (C "#57C6B5" 26), (C "#57C6B5" 5))
$blend.Positions = @(0.0, 0.6, 1.0)
$lgb.InterpolationColors = $blend
$g.FillPolygon($lgb, $poly.ToArray())
$lgb.Dispose()

# 곡선
$penCurve = New-Object System.Drawing.Pen($cSea, 3.5)
$penCurve.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
$g.DrawLines($penCurve, $curve)
$penCurve.Dispose()

# 만조·간조 점
$brBg = New-Object System.Drawing.SolidBrush($cBg)
foreach ($e in $EX) {
  $t = $e[0]; $h = $e[1]
  if ($t -lt $T0 -or $t -gt $T1) { continue }
  if ($h -gt 400) { $r = 8.0; $col = $cOchre } else { $r = 7.0; $col = $cSea }
  $cx = XT $t; $cy = YH $h
  $g.FillEllipse($brBg, ($cx-$r), ($cy-$r), ($r*2), ($r*2))
  $pen = New-Object System.Drawing.Pen($col, 3.5)
  $g.DrawEllipse($pen, ($cx-$r), ($cy-$r), ($r*2), ($r*2))
  $pen.Dispose()
}
$brBg.Dispose()

# ---- 글자 ------------------------------------------------------------------
$fEyebrow = New-Px $famSans  23 ([System.Drawing.FontStyle]::Regular)
$fUrl     = New-Px $famMono  23 ([System.Drawing.FontStyle]::Regular)
$fTitle   = New-Px $famTitle 96 ([System.Drawing.FontStyle]::Regular)
$fSub     = New-Px $famSans  34 ([System.Drawing.FontStyle]::Regular)
$fChip    = New-Px $famSans  24 ([System.Drawing.FontStyle]::Regular)
$fCap     = New-Px $famSans  20 ([System.Drawing.FontStyle]::Regular)

Draw-Tracked   "2026 가을 시즌" $fEyebrow $cInk3 ([single]$M) 106 5
Draw-BaseRight "asdqwe8511.github.io/seohae-jjukkumi-tide" $fUrl $cInk3 ([single]($W-$M)) 106
Draw-Base      "서해 쭈꾸미 물때" $fTitle $cInk ([single]$M) 208
Draw-Base      "물때 · 바다날씨 · 출항 정보를 한 페이지에" $fSub $cInk2 ([single]$M) 266

# 칩
$chips = @("서해 16개 항·포구", "9 · 10 · 11월", "만조 · 간조 시각", "앞바다 예보")
$cx = [single]$M
foreach ($t in $chips) {
  $chipW = (Get-TextWidth $t $fChip) + 40
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $chipY = 304.0; $chipH = 48.0; $chipR = 24.0
  $path.AddArc($cx, $chipY, $chipR*2, $chipH, 90, 180)
  $path.AddArc(($cx+$chipW-$chipR*2), $chipY, $chipR*2, $chipH, 270, 180)
  $path.CloseFigure()
  $penChip = New-Object System.Drawing.Pen($cChip, 1.5)
  $g.DrawPath($penChip, $path)
  $penChip.Dispose(); $path.Dispose()
  Draw-Base $t $fChip $cSea ($cx + 20) 335
  $cx += $chipW + 12
}

Draw-BaseRight "오천항 조석 · 9.1 - 9.2" $fCap $cInk3 ([single]($W-$M)) 386

# ---- 저장 ------------------------------------------------------------------
$g.Dispose()
$bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output ("저장: $outPath  " + (Get-Item $outPath).Length + " bytes")
