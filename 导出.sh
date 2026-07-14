#!/usr/bin/env bash
#
# 名片导出脚本 —— 把某张名片档案里的 HTML 导成高清 PNG
#
# 用法:
#   ./导出.sh 賀陽燐羽            # 导出 名片存档/賀陽燐羽/ 下的 正面 / 背面
#   ./导出.sh 賀陽燐羽 3          # 3 倍分辨率（默认 2 倍）
#   ./导出.sh 名片存档/賀陽燐羽    # 也可直接给路径
#
# 输出：与 HTML 同目录下的 正面.png / 背面.png（圆角透明、无阴影、无页边）
#
set -euo pipefail

# ---- 参数 ----
NAME="${1:-}"
SCALE="${2:-2}"
if [ -z "$NAME" ]; then
  echo "用法: ./导出.sh <档案名或路径> [倍率，默认2]"
  echo "例:  ./导出.sh 賀陽燐羽"
  exit 1
fi

# 项目根目录（脚本所在目录）
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 解析档案目录：先当路径，再当 名片存档/ 下的名字
if [ -d "$NAME" ]; then
  CARD_DIR="$(cd "$NAME" && pwd)"
elif [ -d "$ROOT/名片存档/$NAME" ]; then
  CARD_DIR="$ROOT/名片存档/$NAME"
else
  echo "找不到档案: $NAME"
  echo "（应是 名片存档/ 下的文件夹名，或一个有效路径）"
  exit 1
fi

# ---- 找 Chrome ----
CHROME=""
for c in \
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" \
  "/Applications/Chromium.app/Contents/MacOS/Chromium"; do
  [ -x "$c" ] && CHROME="$c" && break
done
if [ -z "$CHROME" ]; then
  echo "未找到 Chrome / Edge / Chromium，请先安装其一。"
  exit 1
fi

# 画布尺寸 = 名片尺寸 × 倍率
W=$((910 * SCALE))
H=$((550 * SCALE))

echo "档案: $CARD_DIR"
echo "倍率: ${SCALE}x  →  ${W}×${H}"

# ---- 逐个导出 ----
shopt -s nullglob
count=0
for html in "$CARD_DIR/正面.html" "$CARD_DIR/背面.html"; do
  [ -f "$html" ] || continue
  base="$(basename "${html%.html}")"
  tmp="$CARD_DIR/__export_${base}.html"
  out="$CARD_DIR/${base}.png"

  # 注入导出用样式：放大 SCALE 倍、去页边/灰底/阴影，只留名片本体
  node -e "
    const fs=require('fs');
    let h=fs.readFileSync('$html','utf8');
    const css='<style>html{zoom:$SCALE;}html,body{margin:0!important;padding:0!important;background:transparent!important;height:auto!important;display:block!important;}.card-container{box-shadow:none!important;}</style>';
    h=h.replace('</head>', css+'</head>');
    fs.writeFileSync('$tmp', h);
  "

  "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
    --window-size="$W,$H" \
    --default-background-color=00000000 \
    --virtual-time-budget=4000 \
    --screenshot="$out" \
    "file://$tmp" >/dev/null 2>&1

  rm -f "$tmp"
  echo "  ✔ $(basename "$out")"
  count=$((count + 1))
done

if [ "$count" -eq 0 ]; then
  echo "该档案里没有 正面.html / 背面.html"
  exit 1
fi
echo "完成，共导出 $count 张，位于 $CARD_DIR"
