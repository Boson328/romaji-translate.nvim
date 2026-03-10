local M = {}

-- URLエンコード（RFC 3986準拠）
function M.url_encode(str)
	return str:gsub("([^%w%-%.%_%~])", function(c)
		return string.format("%%%02X", string.byte(c))
	end)
end

-- curl で URL を非同期取得し callback(body, err) を呼ぶ
-- 成功時: callback(body, nil)
-- 失敗時: callback(nil, err_message)
function M.fetch(url, callback)
	local cmd = string.format("curl -s -A 'Mozilla/5.0' '%s'", url)
	local body = nil
	local called = false

	-- callback は必ず1回だけ呼ぶ
	local function finish(result, err)
		if called then
			return
		end
		called = true
		callback(result, err)
	end

	vim.fn.jobstart(cmd, {
		stdout_buffered = true,
		on_stdout = function(_, data)
			if not data then
				return
			end
			local chunks = {}
			for _, chunk in ipairs(data) do
				if chunk ~= "" then
					table.insert(chunks, chunk)
				end
			end
			if #chunks > 0 then
				body = table.concat(chunks, "")
			end
		end,
		on_exit = function(_, code)
			if code ~= 0 then
				finish(nil, "curl exited with code " .. code)
			elseif not body or body == "" then
				finish(nil, "empty response")
			else
				finish(body, nil)
			end
		end,
	})
end

-- JSON デコード（失敗時は nil, err を返す）
function M.json_decode(raw)
	local ok, result = pcall(vim.fn.json_decode, raw)
	if not ok then
		return nil, "JSON parse error: " .. tostring(result)
	end
	return result, nil
end

return M
