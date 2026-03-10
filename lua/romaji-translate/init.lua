local M = {}

M.config = {
	notify_on_translate = true,
}

-- ローマ字の命名規則を検出
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

-- snake_case / kebab-case / camelCase などをスペース区切りの単語に分解
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

-- ローマ字→ひらがな 変換テーブル（長いパターンを先に配置）
local ROMAJI_LIST = {
	-- 3文字
	{ "sha", "しゃ" },
	{ "shi", "し" },
	{ "shu", "しゅ" },
	{ "she", "しぇ" },
	{ "sho", "しょ" },
	{ "tsu", "つ" },
	{ "cha", "ちゃ" },
	{ "chi", "ち" },
	{ "chu", "ちゅ" },
	{ "che", "ちぇ" },
	{ "cho", "ちょ" },
	{ "thi", "てぃ" },
	{ "thu", "てゅ" },
	{ "dhi", "でぃ" },
	{ "dhu", "でゅ" },
	{ "nya", "にゃ" },
	{ "nyi", "にぃ" },
	{ "nyu", "にゅ" },
	{ "nye", "にぇ" },
	{ "nyo", "にょ" },
	{ "mya", "みゃ" },
	{ "myu", "みゅ" },
	{ "myo", "みょ" },
	{ "rya", "りゃ" },
	{ "ryu", "りゅ" },
	{ "ryo", "りょ" },
	{ "hya", "ひゃ" },
	{ "hyu", "ひゅ" },
	{ "hyo", "ひょ" },
	{ "bya", "びゃ" },
	{ "byu", "びゅ" },
	{ "byo", "びょ" },
	{ "pya", "ぴゃ" },
	{ "pyu", "ぴゅ" },
	{ "pyo", "ぴょ" },
	{ "kya", "きゃ" },
	{ "kyu", "きゅ" },
	{ "kyo", "きょ" },
	{ "gya", "ぎゃ" },
	{ "gyu", "ぎゅ" },
	{ "gyo", "ぎょ" },
	{ "jya", "じゃ" },
	{ "jyu", "じゅ" },
	{ "jyo", "じょ" },
	{ "dya", "ぢゃ" },
	{ "dyu", "ぢゅ" },
	{ "dyo", "ぢょ" },
	-- 2文字
	{ "ka", "か" },
	{ "ki", "き" },
	{ "ku", "く" },
	{ "ke", "け" },
	{ "ko", "こ" },
	{ "ga", "が" },
	{ "gi", "ぎ" },
	{ "gu", "ぐ" },
	{ "ge", "げ" },
	{ "go", "ご" },
	{ "sa", "さ" },
	{ "si", "し" },
	{ "su", "す" },
	{ "se", "せ" },
	{ "so", "そ" },
	{ "za", "ざ" },
	{ "zi", "じ" },
	{ "zu", "ず" },
	{ "ze", "ぜ" },
	{ "zo", "ぞ" },
	{ "ta", "た" },
	{ "ti", "ち" },
	{ "te", "て" },
	{ "to", "と" },
	{ "da", "だ" },
	{ "di", "ぢ" },
	{ "du", "づ" },
	{ "de", "で" },
	{ "do", "ど" },
	{ "na", "な" },
	{ "ni", "に" },
	{ "nu", "ぬ" },
	{ "ne", "ね" },
	{ "no", "の" },
	{ "ha", "は" },
	{ "hi", "ひ" },
	{ "hu", "ふ" },
	{ "he", "へ" },
	{ "ho", "ほ" },
	{ "ba", "ば" },
	{ "bi", "び" },
	{ "bu", "ぶ" },
	{ "be", "べ" },
	{ "bo", "ぼ" },
	{ "pa", "ぱ" },
	{ "pi", "ぴ" },
	{ "pu", "ぷ" },
	{ "pe", "ぺ" },
	{ "po", "ぽ" },
	{ "ma", "ま" },
	{ "mi", "み" },
	{ "mu", "む" },
	{ "me", "め" },
	{ "mo", "も" },
	{ "ya", "や" },
	{ "yu", "ゆ" },
	{ "yo", "よ" },
	{ "ra", "ら" },
	{ "ri", "り" },
	{ "ru", "る" },
	{ "re", "れ" },
	{ "ro", "ろ" },
	{ "wa", "わ" },
	{ "wo", "を" },
	{ "fa", "ふぁ" },
	{ "fi", "ふぃ" },
	{ "fu", "ふ" },
	{ "fe", "ふぇ" },
	{ "fo", "ふぉ" },
	{ "ja", "じゃ" },
	{ "ji", "じ" },
	{ "ju", "じゅ" },
	{ "je", "じぇ" },
	{ "jo", "じょ" },
	-- 1文字母音（最後に配置）
	{ "a", "あ" },
	{ "i", "い" },
	{ "u", "う" },
	{ "e", "え" },
	{ "o", "お" },
}

-- ローマ字文字列をひらがなに変換
local function romaji_to_hiragana(str)
	str = str:lower()
	local result = {}
	local i = 1
	local len = #str

	while i <= len do
		local matched = false

		-- 促音: 同じ子音が2つ続く（n を除く）
		if i < len and str:sub(i, i) == str:sub(i + 1, i + 1) and str:sub(i, i):match("[bcdfghjklmpqrstvwxyz]") then
			table.insert(result, "っ")
			i = i + 1
			matched = true

		-- nn → ん
		elseif i + 1 <= len and str:sub(i, i + 1) == "nn" then
			table.insert(result, "ん")
			i = i + 2
			matched = true

		-- n の特殊処理: 次が母音・y でなければ「ん」
		-- na/ni/nu/ne/no/nya 等は下のテーブルマッチに任せる
		elseif str:sub(i, i) == "n" then
			local next = str:sub(i + 1, i + 1)
			if next == "" or not next:match("[aeiouy]") then
				table.insert(result, "ん")
				i = i + 1
				matched = true
			end
		end

		-- テーブルを先頭から順に試す（長いパターンが先にあるので正しくマッチ）
		if not matched then
			for _, pair in ipairs(ROMAJI_LIST) do
				local pat, hira = pair[1], pair[2]
				local plen = #pat
				if str:sub(i, i + plen - 1) == pat then
					table.insert(result, hira)
					i = i + plen
					matched = true
					break
				end
			end
		end

		-- どれにもマッチしない文字はそのまま残す
		if not matched then
			table.insert(result, str:sub(i, i))
			i = i + 1
		end
	end

	return table.concat(result, "")
end

-- URL エンコード
local function url_encode(str)
	return str:gsub("([^%w%-%.%_%~ ])", function(c)
		return string.format("%%%02X", string.byte(c))
	end):gsub(" ", "+")
end

-- Google Translate 非公式エンドポイント（APIキー不要）
local function translate_text(text, callback)
	local encoded = url_encode(text)
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

	-- 各パーツをローマ字→ひらがなに変換してスペースで結合
	local hiragana_parts = {}
	for _, part in ipairs(parts) do
		table.insert(hiragana_parts, romaji_to_hiragana(part))
	end
	local hiragana_text = table.concat(hiragana_parts, " ")

	translate_text(hiragana_text, function(translated)
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
				vim.notify(
					string.format("[RomajiTranslate] %s → %s → %s (%s)", word, hiragana_text, result, case_style)
				)
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
