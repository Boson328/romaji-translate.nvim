local M = {}

-- 命名規則を検出
-- 戻り値: "snake_case" | "camelCase" | "PascalCase" | "kebab-case" | "plain"
function M.detect_case(word)
	-- PascalCase: 大文字始まり かつ 2文字目以降にも大文字 かつ区切り文字なし
	if word:match("^%u") and word:match("^.+%u") and not word:match("[_%-]") then
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

-- 識別子をパーツに分解（snake/kebab/camel/Pascal 対応）
function M.split_identifier(word)
	local parts = {}
	if word:match("[_%-]") then
		for part in word:gmatch("[^_%-]+") do
			table.insert(parts, part)
		end
	elseif word:match("%u") then
		-- camelCase / PascalCase: 大文字の前にスペースを挿入して分割
		local spaced = word:gsub("(%u)", function(c)
			return " " .. c:lower()
		end):gsub("^%s", "")
		for part in spaced:gmatch("%S+") do
			table.insert(parts, part)
		end
	else
		table.insert(parts, word)
	end
	return parts
end

-- 英語単語リストを指定の命名規則でフォーマット
function M.format_as_case(words, case_style)
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
		return table.concat(result)
	elseif case_style == "PascalCase" then
		local result = {}
		for _, w in ipairs(words) do
			table.insert(result, w:sub(1, 1):upper() .. w:sub(2):lower())
		end
		return table.concat(result)
	else
		return table.concat(words, " ")
	end
end

-- 翻訳結果の英語テキストを識別子の単語リストに変換
function M.english_to_words(text)
	local words = {}
	for w in text:lower():gsub("[^%a%s]", " "):gmatch("%S+") do
		table.insert(words, w)
	end
	return words
end

-- UTF-8 で 3バイト文字（ひらがな・カタカナ・漢字等）かどうか判定
local function is_japanese_byte(s, pos)
	local b = s:byte(pos)
	return b ~= nil and b >= 0xE3 and b <= 0xEF
end

-- ASCII 識別子文字かどうか
local function is_ascii_word_char(c)
	return c:match("[%w_%-]") ~= nil
end

-- カーソル下の単語範囲を返す（1-indexed バイト位置、inclusive）
-- 戻り値: start_col, end_col
function M.get_word_range(line, col)
	-- col: 0-indexed バイト位置
	local len = #line
	local is_jp = is_japanese_byte(line, col + 1)

	-- 開始位置を左に伸ばす
	local start_col = col + 1 -- 1-indexed
	while start_col > 1 do
		if is_jp then
			local prev = start_col - 3
			if prev >= 1 and is_japanese_byte(line, prev) then
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

	-- 終了位置を右に伸ばす（end_col は inclusive な末尾バイト位置）
	local end_col = col + 1 -- 1-indexed
	while true do
		if is_jp then
			local next_head = end_col + 3
			if next_head <= len and is_japanese_byte(line, next_head) then
				end_col = next_head
			else
				-- 3バイト文字の末尾まで含める
				end_col = math.min(end_col + 2, len)
				break
			end
		else
			if end_col < len and is_ascii_word_char(line:sub(end_col + 1, end_col + 1)) then
				end_col = end_col + 1
			else
				break
			end
		end
	end

	return start_col, end_col
end

-- 先頭バイトで日本語文字かどうかを公開
function M.is_japanese(s, pos)
	return is_japanese_byte(s, pos)
end

return M
