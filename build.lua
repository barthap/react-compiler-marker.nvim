local plugin_dir = debug.getinfo(1, "S").source:match("@(.+/)")
if plugin_dir then
	plugin_dir = plugin_dir:gsub("/lua/$", "")
else
	plugin_dir = vim.fn.stdpath("data") .. "/lazy/react-compiler-marker"
end

print("Installing react-compiler-marker npm dependencies...")

local result = vim.system({ "npm", "install", "--omit", "dev" }, { cwd = plugin_dir }):wait()
if result.code ~= 0 then
	vim.notify("Failed to npm install react-compiler-marker dependencies:\n" .. result.stderr, vim.log.levels.ERROR)
end
