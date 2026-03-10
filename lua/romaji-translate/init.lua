local M = {}

M.config = {
	notify_on_translate = true,
	-- "plain"（区切りなし小文字）のときに使うデフォルトの命名規則
	-- "snake_case" | "camelCase" | "PascalCase" | "kebab-case" | "plain"
	default_case = "snake_case",
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
	{ "tu", "つ" },
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

-- Google IME 非公式API: ひらがな → 漢字変換候補リストを返す
-- callback(candidates): candidates は文字列のリスト（各候補の組み合わせ）
local function hiragana_to_kanji_candidates(text, callback)
	local encoded = url_encode(text)
	local url = string.format("https://www.google.com/transliterate?langpair=ja-Hira|ja&text=%s", encoded)

	local cmd = string.format("curl -s -A 'Mozilla/5.0' '%s'", url)

	vim.fn.jobstart(cmd, {
		stdout_buffered = true,
		on_stdout = function(_, data)
			if not data or #data == 0 then
				callback({ text })
				return
			end

			local raw = table.concat(data, "")
			local ok, decoded = pcall(vim.fn.json_decode, raw)
			if not ok or type(decoded) ~= "table" then
				callback({ text })
				return
			end

			-- レスポンス例: [["とりひき",["取引","取り引き"]],["しょり",["処理","所理"]]]
			-- セグメントごとに候補リストを収集し、組み合わせを生成する
			-- 組み合わせ数が爆発しないよう各セグメント最大3候補に制限
			local MAX_CANDS = 3
			local segments = {}
			for _, segment in ipairs(decoded) do
				local seg_cands = {}
				local raw_cands = segment[2]
				if raw_cands and #raw_cands > 0 then
					for j = 1, math.min(#raw_cands, MAX_CANDS) do
						table.insert(seg_cands, raw_cands[j])
					end
				else
					table.insert(seg_cands, segment[1] or "")
				end
				table.insert(segments, seg_cands)
			end

			-- 全セグメントの候補を組み合わせて候補文字列を生成（最大10件）
			local MAX_RESULTS = 10
			local results = {}
			local seen = {}

			local function combine(seg_idx, current)
				if #results >= MAX_RESULTS then
					return
				end
				if seg_idx > #segments then
					local s = table.concat(current, "")
					if not seen[s] then
						seen[s] = true
						table.insert(results, s)
					end
					return
				end
				for _, cand in ipairs(segments[seg_idx]) do
					table.insert(current, cand)
					combine(seg_idx + 1, current)
					table.remove(current)
					if #results >= MAX_RESULTS then
						return
					end
				end
			end

			combine(1, {})

			if #results == 0 then
				callback({ text })
			else
				callback(results)
			end
		end,
		on_stderr = function(_, _)
			callback({ text })
		end,
	})
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

-- 文字がASCII英数字・記号（ローマ字識別子）かどうか
local function is_ascii_word_char(c)
	return c:match("[%w_%-]") ~= nil
end

-- 文字が日本語（ひらがな・カタカナ・漢字）かどうか（UTF-8バイト列で判定）
-- 日本語は基本的に 3バイト文字（0xE3...）
local function is_japanese_char(s, pos)
	local b = s:byte(pos)
	return b and b >= 0xE3 and b <= 0xEF
end

-- カーソル位置から単語範囲をバイト単位で取得
-- ASCII識別子と日本語文字を両方サポート
local function get_word_range(line, col)
	-- col は 0-indexed バイト位置
	local len = #line

	-- カーソル位置の文字種を判定
	local is_jp = is_japanese_char(line, col + 1)

	local function is_word_byte(pos)
		if is_jp then
			return is_japanese_char(line, pos)
		else
			return is_ascii_word_char(line:sub(pos, pos))
		end
	end

	-- 開始位置を左に伸ばす
	local start_col = col + 1 -- 1-indexed
	while start_col > 1 do
		if is_jp then
			-- 日本語は3バイト単位で戻る
			local prev = start_col - 3
			if prev >= 1 and is_japanese_char(line, prev) then
				start_col = prev
			else
				break
			end
		else
			if is_ascii_word_char(line:sub(start_col - 1, start_col - 1)) then
				start_col = start_col - 1
			else
				break
			end
		end
	end

	-- 終了位置を右に伸ばす
	local end_col = col + 1 -- 1-indexed（inclusive）
	while end_col < len do
		if is_jp then
			local next = end_col + 3
			if next <= len and is_japanese_char(line, next) then
				end_col = next
			else
				-- 3バイト文字の末尾まで含める
				end_col = end_col + 2
				break
			end
		else
			if is_ascii_word_char(line:sub(end_col + 1, end_col + 1)) then
				end_col = end_col + 1
			else
				break
			end
		end
	end
	if is_jp then
		end_col = end_col + 2 -- 3バイト文字の末尾
	end

	return start_col, end_col
end

-- メイン: カーソル下の単語を翻訳して置換
function M.translate_word()
	local pos = vim.api.nvim_win_get_cursor(0)
	local line = vim.api.nvim_get_current_line()
	local col = pos[2] -- 0-indexed バイト位置

	-- 単語範囲を取得（ASCII / 日本語どちらも対応）
	local start_col, end_col = get_word_range(line, col)
	local word = line:sub(start_col, end_col)

	if word == "" then
		vim.notify("[RomajiTranslate] カーソル下に単語がありません", vim.log.levels.WARN)
		return
	end

	local case_style = detect_case(word)
	if case_style == "plain" then
		case_style = M.config.default_case
	end

	-- 日本語かどうか判定してパイプラインを分岐
	local is_jp_input = is_japanese_char(word, 1)

	-- 結果を現在行に適用する
	local function apply_result(result)
		local new_line = line:sub(1, start_col - 1) .. result .. line:sub(end_col + 1)
		vim.api.nvim_set_current_line(new_line)
		vim.api.nvim_win_set_cursor(0, { pos[1], start_col - 1 + #result - 1 })
		if M.config.notify_on_translate then
			vim.notify(string.format("[RomajiTranslate] %s → %s (%s)", word, result, case_style))
		end
	end

	-- vim.ui.select で候補を表示（Noice等が自動でオーバーライドして補完UIになる）
	local function show_select(unique)
		local items = {}
		for _, item in ipairs(unique) do
			table.insert(items, { en = item.en, kanji = item.kanji })
		end

		vim.ui.select(items, {
			prompt = "翻訳候補: ",
			format_item = function(item)
				return string.format("%-30s  %s", item.en, item.kanji)
			end,
		}, function(choice)
			if choice then
				apply_result(choice.en)
			end
		end)
	end

	-- 漢字候補リストを全部並列翻訳し、英語候補が揃ったら選択UIを出す
	local function translate_all_and_select(kanji_candidates)
		local total = #kanji_candidates
		local en_results = {} -- { kanji = "取引処理", en = "transaction_processing" }
		local done = 0

		local function on_all_done()
			vim.schedule(function()
				if #en_results == 0 then
					vim.notify("[RomajiTranslate] 翻訳結果が取得できませんでした", vim.log.levels.ERROR)
					return
				end

				-- 重複除去（英語が同じものは最初だけ残す）
				local seen = {}
				local unique = {}
				for _, item in ipairs(en_results) do
					if not seen[item.en] then
						seen[item.en] = true
						table.insert(unique, item)
					end
				end

				if #unique == 1 then
					apply_result(unique[1].en)
				else
					show_select(unique)
				end
			end)
		end

		for _, kanji in ipairs(kanji_candidates) do
			translate_text(kanji, function(translated)
				local en_words = english_to_words(translated)
				if #en_words > 0 then
					table.insert(en_results, {
						kanji = kanji,
						en = format_as_case(en_words, case_style),
					})
				end
				done = done + 1
				if done == total then
					on_all_done()
				end
			end)
		end
	end

	if is_jp_input then
		-- 日本語入力: そのまま1候補として翻訳
		translate_all_and_select({ word })
	else
		-- ローマ字入力: ローマ字→ひらがな→漢字候補→並列翻訳
		local parts = split_identifier(word)
		local hiragana_parts = {}
		for _, part in ipairs(parts) do
			table.insert(hiragana_parts, romaji_to_hiragana(part))
		end
		local hiragana_text = table.concat(hiragana_parts, " ")

		hiragana_to_kanji_candidates(hiragana_text, function(kanji_candidates)
			translate_all_and_select(kanji_candidates)
		end)
	end
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
