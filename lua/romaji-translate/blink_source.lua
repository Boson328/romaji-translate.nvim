-- blink.cmp custom source
-- 翻訳候補を pending ストアに保存し、get_completions() で返す

local M = {}

-- 翻訳候補の一時ストア
-- { items = [{en, kanji}], row = N (1-indexed), start_char = N (0-indexed), word_len = N }
local pending = nil

function M.set_pending(data)
	pending = data
end

function M.clear_pending()
	pending = nil
end

function M.has_pending()
	return pending ~= nil
end

-- blink.cmp source オブジェクト --

local Source = {}
Source.__index = Source

function Source.new(opts)
	return setmetatable({}, Source)
end

function Source:get_trigger_characters()
	return {}
end

function Source:get_completions(ctx, callback)
	if not pending then
		callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
		return
	end

	local items = {}
	for i, item in ipairs(pending.items) do
		table.insert(items, {
			label = item.en,
			detail = item.kanji,
			insertText = item.en,
			kind = vim.lsp.protocol.CompletionItemKind.Text,
			sortText = string.format("%03d", i),
			textEdit = {
				newText = item.en,
				range = {
					start = { line = pending.row - 1, character = pending.start_char },
					["end"] = { line = pending.row - 1, character = pending.start_char + pending.word_len },
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

function Source:resolve(item, callback)
	callback(item)
end

function Source:execute(ctx, item, callback, default_implementation)
	M.clear_pending()
	default_implementation()
	if callback then
		callback()
	end
end

function M.new(opts)
	return Source.new(opts)
end

return M
