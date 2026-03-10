-- Plugin entrypoint
-- lazy.nvim などが自動でロードする

if vim.g.loaded_romaji_translate then
	return
end
vim.g.loaded_romaji_translate = true

-- デフォルトセットアップ（setup() を呼ばなくても動く）
require("romaji-translate").setup()
