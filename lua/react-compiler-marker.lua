-- React Compiler Marker for Neovim
-- Provides inlay hints showing React Compiler optimization status

local M = {}

-- Configuration
local config = {
	babel_plugin_path = "node_modules/babel-plugin-react-compiler",
	success_emoji = "✨",
	error_emoji = "🚫",
	enabled = true,
}

-- Cache for compilation results
local compilation_cache = {}

-- Cache for hover information per buffer
local hover_cache = {}

-- Setup function to initialize the LSP functionality
function M.setup(opts)
	config = vim.tbl_deep_extend("force", config, opts or {})

	-- Set up autocommands for React/TypeScript files
	local group = vim.api.nvim_create_augroup("ReactCompilerMarker", { clear = true })

	vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "TextChanged", "TextChangedI" }, {
		group = group,
		pattern = { "*.tsx", "*.jsx", "*.ts", "*.js" },
		callback = function(args)
			if config.enabled and args.buf then
				vim.schedule(function()
					-- Additional safety check
					if vim.api.nvim_buf_is_valid(args.buf) then
						M.update_inlay_hints(args.buf)
					end
				end)
			end
		end,
	})

	-- Set up user commands
	vim.api.nvim_create_user_command("ReactCompilerToggle", function()
		config.enabled = not config.enabled
		if config.enabled then
			print("React Compiler Marker enabled ✨")
			M.update_inlay_hints(0)
		else
			print("React Compiler Marker disabled")
			M.clear_inlay_hints(0)
		end
	end, {})

	vim.api.nvim_create_user_command("ReactCompilerCheck", function()
		M.update_inlay_hints(0)
		print("React Compiler markers refreshed ✨")
	end, {})

	-- Add a dedicated command for React Compiler hover info
	vim.api.nvim_create_user_command("ReactCompilerHover", function()
		M.show_react_compiler_hover()
	end, { desc = "Show React Compiler information for component under cursor" })
end

-- Function to run babel-plugin-react-compiler on code
function M.check_react_compiler(code, filename)
	-- Get the directory where this plugin is installed
	local plugin_dir = debug.getinfo(1, "S").source:match("@(.+/)")
	if plugin_dir then
		plugin_dir = plugin_dir:gsub("/lua/$", "")
	else
		plugin_dir = vim.fn.stdpath("data") .. "/lazy/react-compiler-marker"
	end

	local script_path = plugin_dir .. "/nvim/check-react-compiler.js"

	-- Check if our script exists, fallback to node if not
	local cmd
	if vim.fn.filereadable(script_path) == 1 then
		cmd = string.format('node "%s" "%s" "%s"', script_path, config.babel_plugin_path, filename)
	else
		-- Fallback to inline node script
		cmd = string.format(
			'node -e "'
				.. 'const babel = require(\\"@babel/core\\");'
				.. 'const parser = require(\\"@babel/parser\\");'
				.. 'const path = require(\\"path\\");'
				.. "let BabelPluginReactCompiler;"
				.. 'try { BabelPluginReactCompiler = require(path.resolve(\\"%s\\")); } '
				.. 'catch (e) { try { BabelPluginReactCompiler = require(\\"babel-plugin-react-compiler\\"); } '
				.. 'catch (e2) { console.error(JSON.stringify({error: \\"Could not load babel-plugin-react-compiler\\"})); process.exit(1); } }'
				.. "const successfulCompilations = []; const failedCompilations = [];"
				.. "const logger = { logEvent(filename, rawEvent) { const event = { ...rawEvent, filename }; "
				.. 'switch (event.kind) { case \\"CompileSuccess\\": successfulCompilations.push(event); break; '
				.. 'case \\"CompileError\\": case \\"CompileDiagnostic\\": case \\"PipelineError\\": failedCompilations.push(event); break; } } };'
				.. 'const compilerOptions = { noEmit: true, compilationMode: \\"infer\\", panicThreshold: \\"none\\", '
				.. "environment: { enableTreatRefLikeIdentifiersAsRefs: true }, logger };"
				.. 'let code = \\"\\"; process.stdin.setEncoding(\\"utf8\\"); process.stdin.on(\\"readable\\", () => { '
				.. "const chunk = process.stdin.read(); if (chunk !== null) { code += chunk; } }); "
				.. 'process.stdin.on(\\"end\\", () => { try { const ast = parser.parse(code, { sourceFilename: \\"%s\\", '
				.. 'plugins: [\\"typescript\\", \\"jsx\\"], sourceType: \\"module\\" }); '
				.. 'babel.transformFromAstSync(ast, code, { filename: \\"%s\\", plugins: [[BabelPluginReactCompiler, compilerOptions]], '
				.. "configFile: false, babelrc: false }); console.log(JSON.stringify({ successfulCompilations, failedCompilations })); } "
				.. 'catch (error) { console.error(JSON.stringify({ error: error.message })); process.exit(1); } });"',
			config.babel_plugin_path,
			filename,
			filename
		)
	end

	-- Create a temporary file with the code
	local temp_file = vim.fn.tempname()
	local file = io.open(temp_file, "w")
	if not file then
		return { error = "Could not create temp file" }
	end
	file:write(code)
	file:close()

	-- Run the command
	local result = vim.fn.system(cmd .. ' < "' .. temp_file .. '"')
	vim.fn.delete(temp_file)

	-- Parse the result
	local ok, parsed = pcall(vim.fn.json_decode, result)
	if not ok or not parsed then
		return { error = "Failed to parse result: " .. tostring(result) }
	end

	return parsed
end

-- Parse compilation event to extract position information
function M.parse_event(event)
	local function get_loc_value(property, field, default_value)
		if event.detail and event.detail.options then
			if event.detail.options.details and #event.detail.options.details > 0 then
				local detail = event.detail.options.details[1]
				if detail.loc and detail.loc[property] then
					return detail.loc[property][field] or default_value
				end
			end
			if event.detail.options.loc and event.detail.options.loc[property] then
				return event.detail.options.loc[property][field] or default_value
			end
		end
		if event.detail and event.detail.loc and event.detail.loc[property] then
			return event.detail.loc[property][field] or default_value
		end
		return default_value
	end

	local start_line = get_loc_value("start", "line", 1)
	local start_char = get_loc_value("start", "column", 0)
	local reason = event.detail and event.detail.options and event.detail.options.reason or "Unknown reason"
	local description = event.detail and event.detail.options and event.detail.options.description or ""

	return {
		start_line = math.max(0, start_line - 1), -- Convert to 0-based
		start_char = math.max(0, start_char),
		reason = reason ~= vim.NIL and reason or "Unknown reason",
		description = description ~= vim.NIL and description or "",
	}
end

-- Update inlay hints for the given buffer
function M.update_inlay_hints(bufnr)
	bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr

	-- Validate buffer
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	-- Clear existing inlay hints
	M.clear_inlay_hints(bufnr)

	local filename = vim.api.nvim_buf_get_name(bufnr)
	if not filename or filename == "" then
		return
	end

	-- Only process React/TypeScript files
	if not filename:match("%.tsx?$") and not filename:match("%.jsx?$") then
		return
	end

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local code = table.concat(lines, "\n")

	-- Check cache first
	local cache_key = filename .. ":" .. vim.fn.sha256(code)
	if compilation_cache[cache_key] then
		M.apply_inlay_hints(bufnr, compilation_cache[cache_key])
		return
	end

	-- Run React Compiler check
	local result = M.check_react_compiler(code, filename)
	if not result or result.error then
		if result and result.error then
			vim.notify("React Compiler check failed: " .. result.error, vim.log.levels.WARN)
		end
		return
	end

	-- Cache the result
	compilation_cache[cache_key] = result

	-- Apply inlay hints
	M.apply_inlay_hints(bufnr, result)
end

-- Apply inlay hints based on compilation results
function M.apply_inlay_hints(bufnr, result)
	local hints = {}

	-- Function patterns to match for placing hints
	local patterns = {
		"export default async function",
		"export default function",
		"export async function",
		"export function",
		"async function",
		"function",
		"export const",
		"const",
	}

	-- Process successful compilations
	for _, event in ipairs(result.successfulCompilations or {}) do
		local fn_line = (event.fnLoc and event.fnLoc.start and event.fnLoc.start.line or 1) - 1

		if fn_line >= 0 and fn_line < vim.api.nvim_buf_line_count(bufnr) then
			local line_content = vim.api.nvim_buf_get_lines(bufnr, fn_line, fn_line + 1, false)[1] or ""

			local start_col = 0
			for _, pattern in ipairs(patterns) do
				local match_start = line_content:find(pattern, 1, true)
				if match_start then
					start_col = match_start + #pattern - 1
					break
				end
			end

			table.insert(hints, {
				position = { fn_line, start_col },
				label = " " .. config.success_emoji,
				tooltip = config.success_emoji .. " This component has been auto-memoized by React Compiler",
			})
		end
	end

	-- Process failed compilations
	for _, event in ipairs(result.failedCompilations or {}) do
		local fn_line = (event.fnLoc and event.fnLoc.start and event.fnLoc.start.line or 1) - 1

		if fn_line >= 0 and fn_line < vim.api.nvim_buf_line_count(bufnr) then
			local line_content = vim.api.nvim_buf_get_lines(bufnr, fn_line, fn_line + 1, false)[1] or ""

			local start_col = 0
			for _, pattern in ipairs(patterns) do
				local match_start = line_content:find(pattern, 1, true)
				if match_start then
					start_col = match_start + #pattern - 1
					break
				end
			end

			local parsed = M.parse_event(event)
			local tooltip = string.format(
				"%s This component hasn't been memoized by React Compiler\n\nReason: %s\n%s",
				config.error_emoji,
				parsed.reason,
				parsed.description
			)

			table.insert(hints, {
				position = { fn_line, start_col },
				label = " " .. config.error_emoji,
				tooltip = tooltip,
			})
		end
	end

	-- Use virtual text to display hints (compatible with all Neovim versions)
	local ns = vim.api.nvim_create_namespace("react_compiler_marker")
	vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

	for _, hint in ipairs(hints) do
		-- Find the function name position for better tooltip placement
		local line_content = vim.api.nvim_buf_get_lines(bufnr, hint.position[1], hint.position[1] + 1, false)[1] or ""
		local function_name_start, function_name_end

		-- Look for function name patterns
		local patterns = {
			"function%s+([%w_]+)", -- function ComponentName
			"const%s+([%w_]+)%s*=", -- const ComponentName =
			"([%w_]+)%s*%(", -- ComponentName(
		}

		for _, pattern in ipairs(patterns) do
			local match_start, match_end = line_content:find(pattern)
			if match_start then
				-- Extract the function name from the capture group
				local function_name = line_content:match(pattern)
				if function_name then
					-- Find the actual position of the function name within the match
					local name_pos = line_content:find(function_name, match_start)
					if name_pos then
						function_name_start = name_pos - 1 -- Convert to 0-based
						function_name_end = name_pos + string.len(function_name) - 1
					end
				end
				break
			end
		end

		-- Place virtual text
		vim.api.nvim_buf_set_extmark(bufnr, ns, hint.position[1], hint.position[2], {
			virt_text = { { hint.label, "Comment" } },
			virt_text_pos = "inline", -- Insert inline and shift rest of line
		})

		-- Store hover information for this position
		if function_name_start then
			if not hover_cache[bufnr] then
				hover_cache[bufnr] = {}
			end

			table.insert(hover_cache[bufnr], {
				line = hint.position[1],
				start_col = function_name_start,
				end_col = function_name_end or function_name_start + 10,
				tooltip = hint.tooltip,
			})
		end
	end
end

-- Clear inlay hints for the given buffer
function M.clear_inlay_hints(bufnr)
	bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr

	-- Validate buffer
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local ns = vim.api.nvim_create_namespace("react_compiler_marker")

	vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

	-- Clear hover cache for this buffer
	if hover_cache[bufnr] then
		hover_cache[bufnr] = {}
	end
end

-- Function to show React Compiler hover information
function M.show_react_compiler_hover()
	local bufnr = vim.api.nvim_get_current_buf()
	local cursor_pos = vim.api.nvim_win_get_cursor(0)
	local line = cursor_pos[1] - 1 -- Convert to 0-based
	local col = cursor_pos[2]

	-- Check if we have hover information for this buffer
	if not hover_cache[bufnr] then
		return
	end

	-- Find if cursor is over a function name with hover info
	for _, hover_info in ipairs(hover_cache[bufnr]) do
		if hover_info.line == line and col >= hover_info.start_col and col <= hover_info.end_col then
			-- Show the React Compiler tooltip in a floating window
			local lines = vim.split(hover_info.tooltip, "\n")

			-- Create floating window
			local buf = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

			local opts = {
				relative = "cursor",
				width = math.max(20, math.max(unpack(vim.tbl_map(string.len, lines)))),
				height = #lines,
				row = 1,
				col = 0,
				style = "minimal",
				border = "rounded",
				title = " React Compiler ",
				title_pos = "center",
			}

			local win = vim.api.nvim_open_win(buf, false, opts)

			-- Auto-close after 5 seconds or on cursor move
			vim.defer_fn(function()
				if vim.api.nvim_win_is_valid(win) then
					vim.api.nvim_win_close(win, true)
				end
			end, 5000)

			-- Close on cursor move
			local group = vim.api.nvim_create_augroup("ReactCompilerHover", { clear = false })
			vim.api.nvim_create_autocmd("CursorMoved", {
				group = group,
				buffer = bufnr,
				once = true,
				callback = function()
					if vim.api.nvim_win_is_valid(win) then
						vim.api.nvim_win_close(win, true)
					end
				end,
			})

			break
		end
	end
end

return M
