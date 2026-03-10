# romaji-translate.nvim

ローマ字で書いた識別子（関数名・変数名）を `:RomajiTranslate` するだけで英語に変換するNeovimプラグイン。

- **APIキー不要** — Google翻訳の非公式エンドポイントを使用
- **命名規則を自動検出** — 元のスタイル（snake_case / camelCase / PascalCase / kebab-case）を維持
- **複数候補を選択** — 漢字の解釈が複数ある場合は `vim.ui.select` で選べる

## 動作例

```
torihiki_shori  →  transaction_processing
kyakuSousa      →  customerOperation
NyukinKanri     →  DepositManagement
客の数          →  number_of_customers
取引処理        →  transaction_processing
```

複数候補がある場合：

```
sanshou  →  [ reference             参照 
              japanese_pepper       山椒
              tree_chants           3唱  ]  ← vim.ui.select で選択
```

## インストール

### lazy.nvim

```lua
{
  "boson328/romaji-translate.nvim",
  opts = {
    notify_on_translate = true,  -- 変換後に通知を表示するか（デフォルト: true）
    default_case        = "snake_case",  -- 区切り文字なし（plain）の識別子に使う命名規則
  }
}
```

## 使い方

ローマ字（または日本語）の識別子にカーソルを置いて実行：

```vim
:RomajiTranslate
```

キーマップの例：

```lua
vim.keymap.set("n", "<leader>rt", "<cmd>RomajiTranslate<CR>", { desc = "ローマ字→英語変換" })
```

## 命名規則の検出

| 入力 | 検出 | 出力例 |
|------|------|--------|
| `word_word` | snake_case | `transaction_processing` |
| `word-word` | kebab-case | `transaction-processing` |
| `wordWord`  | camelCase  | `transactionProcessing`  |
| `WordWord`  | PascalCase | `TransactionProcessing`  |
| `word`      | plain → `default_case` を使用 | |

## 候補選択UI

複数の英語候補がある場合は `vim.ui.select` で表示されます。
おすすめはNoice.nvimです

```lua
-- telescope-ui-select の場合
{ "nvim-telescope/telescope-ui-select.nvim",
  config = function()
    require("telescope").load_extension("ui-select")
  end }

-- dressing.nvim の場合（設定不要）
{ "stevearc/dressing.nvim" }

-- noice.nvim の場合（設定不要）
{ "folke/noice.nvim" }
```

## 変換パイプライン

```
識別子（ローマ字）
  └─ split（snake/camel/Pascal/kebab を分解）
      └─ romaji → ひらがな
          └─ Google IME API → 漢字候補（複数）
              └─ 全候補を並列翻訳（Google翻訳）
                  └─ 重複除去 → 1件なら即適用 / 複数なら vim.ui.select
```

日本語入力の場合はローマ字変換をスキップして直接翻訳します。

## 要件

- Neovim 0.9+
- `curl`
