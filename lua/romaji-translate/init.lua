local M = {}

M.config = {
	notify_on_translate = true,
}

-- ローマ字の命名規則を検出
-- 戻り値: "snake_case" | "camelCase" | "PascalCase" | "kebab-case" | "plain"
local function detect_case(word)
	if word:match("^%u") and word:match("%u") and not word:match("[_%-]") then
		return "PascalCase"
	elseif word:match("^%l") and word:match("%u") then
		return "camelCase"
	elseif word:match("_") then
		return "snake_case"
	elseif word:match("%-") then
		return "kebab-case"
	else
		return "plain"
	end
end

-- snake_case / kebab-case などをスペース区切りの単語に分解
local function split_identifier(word)
	local parts = {}

	if word:match("[_%-]") then
		for part in word:gmatch("[^_%-]+") do
			table.insert(parts, part)
		end
	elseif word:match("%u") then
		local spaced = word:gsub("(%u)", function(c)
			return " " .. c:lower()
		end):gsub("^ ", "")
		for part in spaced:gmatch("%S+") do
			table.insert(parts, part)
		end
	else
		table.insert(parts, word)
	end

	return parts
end

-- 検出したケースで英語単語リストを再フォーマット
local function format_as_case(words, case_style)
	if case_style == "snake_case" then
		return table.concat(words, "_"):lower()
	elseif case_style == "kebab-case" then
		return table.concat(words, "-"):lower()
	elseif case_style == "camelCase" then
		local result = {}
		for i, w in ipairs(words) do
			if i == 1 then
				table.insert(result, w:lower())
			else
				table.insert(result, w:sub(1, 1):upper() .. w:sub(2):lower())
			end
		end
		return table.concat(result, "")
	elseif case_style == "PascalCase" then
		local result = {}
		for _, w in ipairs(words) do
			table.insert(result, w:sub(1, 1):upper() .. w:sub(2):lower())
		end
		return table.concat(result, "")
	else
		return table.concat(words, " ")
	end
end

-- URL エンコード
local function url_encode(str)
	return str:gsub("([^%w%-%.%_%~ ])", function(c)
		return string.format("%%%02X", string.byte(c))
	end):gsub(" ", "+")
end

-- Google Translate 非公式エンドポイント（APIキー不要）
-- レスポンス例: [[["Hello","こんにちは",...]],null,"en",...]
local function translate_text(text, callback)
	-- ローマ字をスペース区切りに正規化
	local spaced = text:gsub("[_%-]", " "):gsub("(%u)", " %1"):lower():gsub("^ ", "")

	local encoded = url_encode(spaced)
	local url =
		string.format("https://translate.googleapis.com/translate_a/single?client=gtx&dt=t&sl=ja&tl=en&q=%s", encoded)

	local cmd = string.format("curl -s -A 'Mozilla/5.0' '%s'", url)

	vim.fn.jobstart(cmd, {
		stdout_buffered = true,
		on_stdout = function(_, data)
			if not data or #data == 0 then
				vim.notify("[RomajiTranslate] レスポンスが空です", vim.log.levels.ERROR)
				return
			end

			local raw = table.concat(data, "")
			local ok, decoded = pcall(vim.fn.json_decode, raw)
			if not ok or type(decoded) ~= "table" then
				vim.notify("[RomajiTranslate] JSONパースエラー: " .. raw, vim.log.levels.ERROR)
				return
			end

			-- レスポンス構造: [[["翻訳結果", "原文", ...], ...], null, "ja", ...]
			local translated = decoded[1] and decoded[1][1] and decoded[1][1][1]

			if translated and translated ~= "" then
				callback(translated)
			else
				vim.notify("[RomajiTranslate] 翻訳結果が取得できませんでした", vim.log.levels.ERROR)
			end
		end,
		on_stderr = function(_, data)
			if data and #data > 0 and data[1] ~= "" then
				vim.notify("[RomajiTranslate] curl エラー: " .. table.concat(data, ""), vim.log.levels.ERROR)
			end
		end,
	})
end

-- 翻訳結果の英語テキストを識別子の単語リストに変換
local function english_to_words(text)
	local words = {}
	local cleaned = text:lower():gsub("[^%a%s]", " ")
	for w in cleaned:gmatch("%S+") do
		table.insert(words, w)
	end
	return words
end

-- メイン: カーソル下の単語を翻訳して置換
function M.translate_word()
	local word = vim.fn.expand("<cword>")
	if word == "" then
		vim.notify("[RomajiTranslate] カーソル下に単語がありません", vim.log.levels.WARN)
		return
	end

	local case_style = detect_case(word)
	local parts = split_identifier(word)
	local romaji_text = table.concat(parts, " ")

	translate_text(romaji_text, function(translated)
		local en_words = english_to_words(translated)
		if #en_words == 0 then
			vim.notify("[RomajiTranslate] 英語の単語が取得できませんでした", vim.log.levels.ERROR)
			return
		end

		local result = format_as_case(en_words, case_style)

		vim.schedule(function()
			local pos = vim.api.nvim_win_get_cursor(0)
			local line = vim.api.nvim_get_current_line()
			local col = pos[2]

			-- 単語の開始・終了位置を探す
			local start_col = col
			while start_col > 0 and line:sub(start_col, start_col):match("[%w_%-]") do
				start_col = start_col - 1
			end
			if not line:sub(start_col, start_col):match("[%w_%-]") then
				start_col = start_col + 1
			end

			local end_col = col + 1
			while end_col <= #line and line:sub(end_col, end_col):match("[%w_%-]") do
				end_col = end_col + 1
			end

			local new_line = line:sub(1, start_col - 1) .. result .. line:sub(end_col)
			vim.api.nvim_set_current_line(new_line)
			vim.api.nvim_win_set_cursor(0, { pos[1], start_col - 1 + #result - 1 })

			if M.config.notify_on_translate then
				vim.notify(string.format("[RomajiTranslate] %s → %s (%s)", word, result, case_style))
			end
		end)
	end)
end

-- セットアップ
function M.setup(opts)
	opts = opts or {}
	M.config = vim.tbl_deep_extend("force", M.config, opts)

	vim.api.nvim_create_user_command("RomajiTranslate", function()
		M.translate_word()
	end, { desc = "ローマ字の識別子を英語に翻訳して置換" })
end

return M
