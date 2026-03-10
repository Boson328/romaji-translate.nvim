# romaji-translate.nvim

ローマ字で書いた識別子（関数名・変数名）をカーソル下で `:RomajiTranslate` するだけで英語に変換するNeovimプラグイン。
命名規則（snake_case / camelCase / PascalCase / kebab-case）を自動検出し、元のスタイルを維持したまま変換します。

## 動作例

| 入力 | 変換後 |
|------|--------|
| `torihiki_shori` | `transaction_processing` |
| `kyakuSousa` | `customerOperation` |
| `NyukinKanri` | `DepositManagement` |
| `get-user-joho` | `get-user-information` |

## インストール

### lazy.nvim

```lua
{
  "yourname/romaji-translate.nvim",
  config = function()
    require("romaji-translate").setup({
      api_key = "YOUR_GOOGLE_TRANSLATE_API_KEY",
      -- または環境変数 GOOGLE_TRANSLATE_API_KEY を設定すれば不要
    })
  end,
}
```

### 環境変数でAPIキーを渡す場合

```bash
export GOOGLE_TRANSLATE_API_KEY="AIza..."
```

`setup()` で `api_key` を省略すると自動的に環境変数から読みます。

## 使い方

1. ローマ字の識別子にカーソルを置く
2. `:RomajiTranslate` を実行

キーマップを設定したい場合：

```lua
vim.keymap.set("n", "<leader>rt", "<cmd>RomajiTranslate<CR>", { desc = "ローマ字→英語変換" })
```

## セットアップオプション

```lua
require("romaji-translate").setup({
  api_key = nil,              -- Google Translate APIキー（省略時は環境変数から取得）
  notify_on_translate = true, -- 変換後に通知を表示するか
})
```

## 命名規則の検出ルール

| 入力パターン | 検出ケース |
|-------------|-----------|
| `word_word` | snake_case |
| `word-word` | kebab-case |
| `wordWord`  | camelCase  |
| `WordWord`  | PascalCase |
| `word`      | plain（スペース区切り）|

## 必要なもの

- Neovim 0.8+
- `curl` コマンド
- Google Translate API キー（Cloud Translation API v2）
