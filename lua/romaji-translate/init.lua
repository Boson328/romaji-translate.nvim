local api = require("romaji-translate.api")
local romaji = require("romaji-translate.romaji")
local word = require("romaji-translate.word")

local M = {}

M.config = {
	notify_on_translate = true,
	-- "plain"（区切りなし）の識別子に使うデフォルト命名規則
	-- "snake_case" | "camelCase" | "PascalCase" | "kebab-case"
	default_case = "snake_case",
}

-- 識別子をひらがなに変換（split → 各パーツをローマ字変換 → 結合）
local function identifier_to_hiragana(w)
	local parts = word.split_identifier(w)
	local hira = {}
	for _, part in ipairs(parts) do
		table.insert(hira, romaji.to_hiragana(part))
	end
	return table.concat(hira, " ")
end

-- 翻訳候補リスト { en, kanji }[] を重複除去して返す
local function dedup(items)
	local seen = {}
	local result = {}
	for _, item in ipairs(items) do
		if not seen[item.en] then
			seen[item.en] = true
			table.insert(result, item)
		end
	end
	return result
end

-- vim.ui.select で候補を表示し、選択されたものを callback(en) で返す
-- telescope-ui-select / dressing.nvim が入っていれば自動でそのUIになる
local function select_candidate(candidates, callback)
	vim.ui.select(candidates, {
		prompt = "翻訳候補: ",
		format_item = function(item)
			return string.format("%-30s  %s", item.en, item.kanji)
		end,
	}, function(choice)
		if choice then
			callback(choice.en)
		end
	end)
end

-- 漢字候補リストを並列翻訳し、英語候補が揃ったら callback(unique_items) を呼ぶ
local function translate_all(kanji_candidates, case_style, callback)
	local total = #kanji_candidates
	local results = {}
	local done = 0

	local function on_done()
		done = done + 1
		if done == total then
			vim.schedule(function()
				callback(dedup(results))
			end)
		end
	end

	for _, kanji in ipairs(kanji_candidates) do
		api.translate_ja_to_en(kanji, function(translated, err)
			if not err and translated then
				local words = word.english_to_words(translated)
				if #words > 0 then
					table.insert(results, {
						kanji = kanji,
						en = word.format_as_case(words, case_style),
					})
				end
			end
			on_done()
		end)
	end
end

-- カーソル下の単語を翻訳して置換するメイン処理
function M.translate_word()
	local pos = vim.api.nvim_win_get_cursor(0)
	local line = vim.api.nvim_get_current_line()
	local col = pos[2] -- 0-indexed バイト位置

	local start_col, end_col = word.get_word_range(line, col)
	local w = line:sub(start_col, end_col)

	if w == "" then
		vim.notify("[RomajiTranslate] カーソル下に単語がありません", vim.log.levels.WARN)
		return
	end

	local case_style = word.detect_case(w)
	if case_style == "plain" then
		case_style = M.config.default_case
	end

	-- 結果を行に適用（非同期後なので行を取り直す）
	local function apply(en)
		local cur = vim.api.nvim_get_current_line()
		local new_line = cur:sub(1, start_col - 1) .. en .. cur:sub(end_col + 1)
		vim.api.nvim_set_current_line(new_line)
		vim.api.nvim_win_set_cursor(0, { pos[1], start_col - 1 + #en - 1 })
		if M.config.notify_on_translate then
			vim.notify(string.format("[RomajiTranslate] %s → %s (%s)", w, en, case_style))
		end
	end

	-- 翻訳候補が揃ったら表示 or 即適用
	local function on_candidates(unique)
		if #unique == 0 then
			vim.notify("[RomajiTranslate] 翻訳結果が取得できませんでした", vim.log.levels.ERROR)
			return
		end
		if #unique == 1 then
			apply(unique[1].en)
		else
			select_candidate(unique, apply)
		end
	end

	local is_jp = word.is_japanese(w, 1)

	if is_jp then
		-- 日本語入力: そのまま翻訳
		translate_all({ w }, case_style, on_candidates)
	else
		-- ローマ字入力: ローマ字 → ひらがな → 漢字候補 → 並列翻訳
		local hiragana = identifier_to_hiragana(w)
		api.hiragana_to_kanji(hiragana, function(kanji_candidates, _)
			translate_all(kanji_candidates, case_style, on_candidates)
		end)
	end
end

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	vim.api.nvim_create_user_command("RomajiTranslate", function()
		M.translate_word()
	end, { desc = "ローマ字の識別子を英語に翻訳して置換" })
end

return M
