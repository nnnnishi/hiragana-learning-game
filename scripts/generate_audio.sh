#!/bin/bash
# VOICEVOX音声ファイル生成スクリプト
# 前提: VOICEVOXローカルサーバーが localhost:50021 で起動していること
#
# 使い方:
#   bash scripts/generate_audio.sh
#
# 生成先: ./audio/

set -euo pipefail

VOICEVOX_URL="http://localhost:50021"
SPEAKER=20  # もち子さん
OUTPUT_DIR="./audio"

mkdir -p "$OUTPUT_DIR"

# VOICEVOXサーバーの起動確認
if ! curl -s "${VOICEVOX_URL}/version" > /dev/null 2>&1; then
  echo "❌ VOICEVOXサーバーに接続できません (${VOICEVOX_URL})"
  echo "   VOICEVOXを起動してから再実行してください。"
  exit 1
fi

echo "✅ VOICEVOXサーバー接続OK ($(curl -s ${VOICEVOX_URL}/version))"
echo ""

# ひらがな46文字
HIRAGANA=(
  あ い う え お
  か き く け こ
  さ し す せ そ
  た ち つ て と
  な に ぬ ね の
  は ひ ふ へ ほ
  ま み む め も
  や ゆ よ
  ら り る れ ろ
  わ を ん
)

# 褒め言葉（ファイル名:テキスト のペア）
PRAISE_LIST=(
  "sugoi:すごい"
  "yattane:やったね"
  "tensai:てんさい"
  "kakkoii:かっこいい"
  "subarashii:すばらしい"
  "yattane_big:やったね！すごいね！"
)

TMPFILE=$(mktemp)
trap "rm -f $TMPFILE" EXIT

generate_wav() {
  local text="$1"
  local filename="$2"
  local output_path="${OUTPUT_DIR}/${filename}.wav"

  if [ -f "$output_path" ] && [ "$(wc -c < "$output_path")" -gt 1000 ]; then
    echo "  ⏭  スキップ (既存): ${filename}.wav"
    return
  fi

  # audio_queryを生成 → 一時ファイルに保存
  curl -s -X POST \
    -G "${VOICEVOX_URL}/audio_query" \
    --data-urlencode "text=${text}" \
    -d "speaker=${SPEAKER}" \
    -o "$TMPFILE"

  if [ ! -s "$TMPFILE" ]; then
    echo "  ❌ audio_query失敗: ${text}"
    return 1
  fi

  # 音声合成（一時ファイルから読み込み）
  curl -s -X POST \
    "${VOICEVOX_URL}/synthesis?speaker=${SPEAKER}" \
    -H "Content-Type: application/json" \
    -d @"$TMPFILE" \
    -o "$output_path"

  if [ -f "$output_path" ] && [ "$(wc -c < "$output_path")" -gt 1000 ]; then
    echo "  ✅ 生成完了: ${filename}.wav ($(wc -c < "$output_path") bytes)"
  else
    echo "  ❌ 生成失敗: ${filename}.wav"
    rm -f "$output_path"
    return 1
  fi
}

# ひらがな音声の生成
echo "📝 ひらがな音声を生成中... (${#HIRAGANA[@]}文字)"
echo "---"
for char in "${HIRAGANA[@]}"; do
  generate_wav "$char" "$char"
done

echo ""
echo "🎉 褒め言葉の音声を生成中... (${#PRAISE_LIST[@]}個)"
echo "---"
for entry in "${PRAISE_LIST[@]}"; do
  key="${entry%%:*}"
  text="${entry#*:}"
  generate_wav "$text" "$key"
done

echo ""
echo "🎊 完了！"
echo "   生成先: ${OUTPUT_DIR}/"
ls -la "${OUTPUT_DIR}/" | tail -5
echo "   合計: $(ls -1 ${OUTPUT_DIR}/*.wav 2>/dev/null | wc -l | tr -d ' ') ファイル"
