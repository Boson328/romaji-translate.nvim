local M = {}

-- 長いパターンを先頭に置くことで貪欲マッチを保証する
local ROMAJI_TABLE = {
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
function M.to_hiragana(str)
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

		-- n: 次が母音・y でなければ「ん」（na/ni 等はテーブルマッチに委譲）
		elseif str:sub(i, i) == "n" then
			local nxt = str:sub(i + 1, i + 1)
			if nxt == "" or not nxt:match("[aeiouy]") then
				table.insert(result, "ん")
				i = i + 1
				matched = true
			end
		end

		-- テーブルを先頭から順に試す（長いパターンが先なので正しくマッチ）
		if not matched then
			for _, pair in ipairs(ROMAJI_TABLE) do
				local pat, hira = pair[1], pair[2]
				if str:sub(i, i + #pat - 1) == pat then
					table.insert(result, hira)
					i = i + #pat
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

	return table.concat(result)
end

return M
