#!/usr/bin/env bash
# ヘッドレス Chrome で tests.html を実行し、全テストが成功したか判定する。
#   使い方: CHROME=/path/to/chrome ./run-tests.sh   （CHROME 未指定なら google-chrome）
set -euo pipefail
cd "$(dirname "$0")"

CHROME="${CHROME:-google-chrome}"

# 使えるポートを探してサーバーを起動する（Windows の予約済みポート範囲や使用中ポートを避ける）
SERVER=""
trap '[ -n "$SERVER" ] && kill $SERVER 2>/dev/null || true' EXIT
for PORT in ${PORT:-} 18731 18732 18733 28731 38731; do
  python -m http.server "$PORT" >/dev/null 2>&1 &
  SERVER=$!
  for _ in $(seq 1 20); do
    curl -sf "http://127.0.0.1:$PORT/tests.html" >/dev/null && break 2
    kill -0 "$SERVER" 2>/dev/null || break      # 起動に失敗して終了していたら次のポートへ
    sleep 0.5
  done
  SERVER=""
done
[ -n "$SERVER" ] || { echo "テスト用サーバーを起動できるポートが見つかりません" >&2; exit 1; }

DOM=$("$CHROME" --headless=new --no-sandbox --disable-gpu --virtual-time-budget=120000 \
  --dump-dom "http://127.0.0.1:$PORT/tests.html")

SUMMARY=$(printf '%s' "$DOM" | grep -o '<p id="summary"[^>]*>[^<]*' | sed 's/<[^>]*>//')
echo "結果: $SUMMARY"
printf '%s' "$DOM" | grep -o '<span class="ng">FAIL</span>[^<]*\(<small>[^<]*\)\?' | sed 's/<[^>]*>/ /g' || true

case "$SUMMARY" in
  *"件成功"*) [[ "$SUMMARY" == *"失敗"* ]] && exit 1 || exit 0 ;;
  *) echo "テスト結果を取得できませんでした" >&2; exit 1 ;;
esac
