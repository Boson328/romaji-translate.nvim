local util = require("romaji-translate.util")

local M = {}

local IME_URL = "https://www.google.com/transliterate?langpair=ja-Hira|ja&text=%s"
local TRANS_URL = "https://translate.googleapis.com/translate_a/single?client=gtx&dt=t&sl=ja&tl=en&q=%s"

local MAX_CANDS_PER_SEG = 3
local MAX_COMBINATIONS = 10

-- ひらがな → 漢字候補リスト
-- callback(candidates: string[], err: string|nil)
function M.hiragana_to_kanji(text, callback)
	local url = IME_URL:format(util.url_encode(text))

	util.fetch(url, function(body, err)
		if err then
			callback({ text }, nil)
			return
		end

		local decoded, decode_err = util.json_decode(body)
		if decode_err or type(decoded) ~= "table" then
			callback({ text }, nil)
			return
		end

		-- レスポンス例: [["とりひき",["取引","取り引き"]],["しょり",["処理","所理"]]]
		-- セグメントごとに候補を収集し、組み合わせを生成する
		local segments = {}
		for _, segment in ipairs(decoded) do
			local cands = {}
			local raw_cands = segment[2]
			if raw_cands and #raw_cands > 0 then
				for j = 1, math.min(#raw_cands, MAX_CANDS_PER_SEG) do
					table.insert(cands, raw_cands[j])
				end
			else
				table.insert(cands, segment[1] or "")
			end
			table.insert(segments, cands)
		end

		-- 全セグメントの組み合わせを生成（最大 MAX_COMBINATIONS 件）
		local results = {}
		local seen = {}

		local function combine(seg_idx, current)
			if #results >= MAX_COMBINATIONS then
				return
			end
			if seg_idx > #segments then
				local s = table.concat(current)
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
				if #results >= MAX_COMBINATIONS then
					return
				end
			end
		end

		combine(1, {})
		callback(#results > 0 and results or { text }, nil)
	end)
end

-- 日本語テキスト → 英語翻訳
-- callback(translated: string|nil, err: string|nil)
function M.translate_ja_to_en(text, callback)
	local url = TRANS_URL:format(util.url_encode(text))

	util.fetch(url, function(body, err)
		if err then
			callback(nil, err)
			return
		end

		local decoded, decode_err = util.json_decode(body)
		if decode_err or type(decoded) ~= "table" then
			callback(nil, decode_err or "invalid response")
			return
		end

		local translated = decoded[1] and decoded[1][1] and decoded[1][1][1]
		if translated and translated ~= "" then
			callback(translated, nil)
		else
			callback(nil, "empty translation")
		end
	end)
end

return M
