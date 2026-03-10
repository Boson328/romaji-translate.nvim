-- blink.cmp の custom source として機能するモジュール
-- romaji-translate が翻訳候補をここに書き込み、
-- Blink が補完トリガー時に get_completions() を呼んで候補を返す

local source = {}

-- 翻訳候補を一時保存するストア
-- { items = [...], word = "元の単語", start_col = N, row = N }
local pending = nil

-- romaji-translate 本体から候補をセットする
function source.set_pending(data)
	pending = data
end

function source.clear_pending()
	pending = nil
end

function source.has_pending()
	return pending ~= nil
end

-- blink.cmp source API --

function source:new()
	return setmetatable({}, { __index = self })
end

function source:get_trigger_characters()
	return {}
end

-- blink が補完を要求してきたときに候補を返す
function source:get_completions(ctx, callback)
	if not pending then
		callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
		return
	end

	local items = {}
	for i, item in ipairs(pending.items) do
		table.insert(items, {
			label = item.en,
			detail = item.kanji, -- 右側に漢字を表示
			insertText = item.en,
			kind = 1, -- Text kind
			sortText = string.format("%03d", i), -- 順番を保持
			-- カーソル位置から単語先頭までを置換範囲に指定
			textEdit = {
				newText = item.en,
				range = {
					start = { line = pending.row - 1, character = pending.start_col - 1 },
					["end"] = { line = pending.row - 1, character = pending.start_col - 1 + #pending.current_text },
				},
			},
		})
	end

	callback({
		is_incomplete_forward = false,
		is_incomplete_backward = false,
		items = items,
	})
end

-- 補完が確定 or キャンセルされたらクリア
function source:resolve(item, callback)
	callback(item)
end

function source:execute(ctx, item)
	source.clear_pending()
end

return source
