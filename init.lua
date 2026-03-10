local M = {}

M.config = {
	api_key = nil, -- Google Translate API key
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

	-- snake_case or kebab-case
	if word:match("[_%-]") then
		for part in word:gmatch("[^_%-]+") do
			table.insert(parts, part)
		end
	-- camelCase or PascalCase
	elseif word:match("%u") then
		-- 大文字の前にスペースを入れる（最初の大文字は除く）
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
		-- plain: スペース区切りのままにする
		return table.concat(words, " ")
	end
end

-- Google Translate API 呼び出し（curl経由）
local function translate_text(text, callback)
	local api_key = M.config.api_key
	if not api_key then
		vim.notify("[RomajiTranslate] GOOGLE_TRANSLATE_API_KEY が設定されていません", vim.log.levels.ERROR)
		return
	end

	-- ローマ字をスペース区切りにして読みやすくする
	local spaced = text:gsub("[_%-]", " "):gsub("(%u)", " %1"):lower():gsub("^ ", "")

	local url = string.format("https://translation.googleapis.com/language/translate/v2?key=%s", api_key)

	local body = vim.fn.json_encode({
		q = spaced,
		source = "ja",
		target = "en",
		format = "text",
	})

	-- 一時ファイルにbodyを書き出す
	local tmpfile = vim.fn.tempname()
	vim.fn.writefile({ body }, tmpfile)

	local cmd = string.format("curl -s -X POST '%s' -H 'Content-Type: application/json' -d @%s", url, tmpfile)

	-- 非同期実行
	vim.fn.jobstart(cmd, {
		stdout_buffered = true,
		on_stdout = function(_, data)
			vim.fn.delete(tmpfile)
			if not data or #data == 0 then
				vim.notify("[RomajiTranslate] レスポンスが空です", vim.log.levels.ERROR)
				return
			end

			local raw = table.concat(data, "")
			local ok, decoded = pcall(vim.fn.json_decode, raw)
			if not ok or not decoded then
				vim.notify("[RomajiTranslate] JSONパースエラー: " .. raw, vim.log.levels.ERROR)
				return
			end

			if decoded.error then
				vim.notify(
					"[RomajiTranslate] APIエラー: " .. (decoded.error.message or "unknown"),
					vim.log.levels.ERROR
				)
				return
			end

			local translated = decoded.data
				and decoded.data.translations
				and decoded.data.translations[1]
				and decoded.data.translations[1].translatedText

			if translated then
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
	-- 小文字化・記号除去・スペース分割
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

		-- カーソル下の単語を置換
		vim.schedule(function()
			-- ciw で単語を削除して挿入
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

			-- カーソルを変換後の単語末尾に移動
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

	-- 環境変数からAPIキーを自動取得（設定がない場合）
	if not M.config.api_key then
		M.config.api_key = vim.env.GOOGLE_TRANSLATE_API_KEY
	end

	-- コマンド登録
	vim.api.nvim_create_user_command("RomajiTranslate", function()
		M.translate_word()
	end, { desc = "ローマ字の識別子を英語に翻訳して置換" })
end

return M
