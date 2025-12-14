# React Compiler Marker for Neovim ✨

A Neovim configuration that provides inlay hints showing React Compiler optimization status, similar to the [VSCode extension](https://marketplace.visualstudio.com/items?itemName=blazejkustra.react-compiler-marker).

> [!NOTE]
> This is a Neovim port of the original **`react-compiler-marker` VSCode/Cursor extension**. If you're looking for the original extension code, go to the **[blazejkustra/react-compiler-marker](https://github.com/blazejkustra/react-compiler-marker)** repository.

## Features

- Shows ✨ emoji next to React components that have been successfully optimized by React Compiler
- Shows 🚫 emoji next to components that failed to be memoized
- Hover tooltips with detailed information about compilation status and failure reasons
- Automatic updates on file changes
- Toggle functionality to enable/disable markers
- Manual refresh command

## Requirements

- Neovim 0.9+ (for inlay hint support)
- Node.js
- `babel-plugin-react-compiler` installed in your project or globally
- `@babel/core` and `@babel/parser` packages

## Installation

### Using lazy.nvim

Add the following to your lazy.nvim configuration:

```lua
{
  "barthap/react-compiler-marker.nvim",
  opts = {
    -- Optional configuration
    babel_plugin_path = 'node_modules/babel-plugin-react-compiler',
    success_emoji = '✨',
    error_emoji = '🚫',
    enabled = true,
  },
  -- Only load for React/TypeScript files
  ft = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
}
```

### Using packer.nvim

First, install the required Node.js dependencies in your project:

```bash
npm install --global babel-plugin-react-compiler @babel/core @babel/parser
```

Then add this to your configuration:

```lua
use {
  "barthap/react-compiler-marker.nvim",
  config = function()
    require("react-compiler-marker").setup()
  end,
  ft = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
}
```

### Manual Installation

1. Copy the `nvim-lsp` directory to your Neovim configuration directory
2. Add the following to your `init.lua`:

```lua
require("react-compiler-marker").setup()
```

## Configuration

The setup function accepts the following options:

```lua
require("react-compiler-marker").setup({
  -- Path to babel-plugin-react-compiler (relative to project root)
  babel_plugin_path = 'node_modules/babel-plugin-react-compiler',

  -- Emoji to show for successfully optimized components
  success_emoji = '✨',

  -- Emoji to show for components that failed to be memoized
  error_emoji = '🚫',

  -- Whether the plugin is enabled by default
  enabled = true,
})
```

### Mapping a key to show a hover tooltip

Example keymap using native `vim.keymap.set()` API:

```lua
vim.keymap.set("n", "<leader>k", function()
  -- Optionally show normal LSP hover; useful when binding to the same key as other the LSP inspector, e.g. Shift-K.
  -- vim.lsp.buf.hover()

  vim.defer_fn(function()
    vim.cmd("ReactCompilerHover") -- Then show React Compiler info
  end, 100) -- Small delay to let LSP hover appear first
end, { desc = "Show React Compiler info" })
```

The above can be done during plugin initialization. An example for lazy.nvim:

```lua
{
  "barthap/react-compiler-marker.nvim",
  -- ... standard plugin config (described above)
  init = function()
    vim.keymap.set(
      -- put the above keymap snippet here
    )
  end
}
```

## Commands

- `:ReactCompilerToggle` - Toggle React Compiler markers on/off
- `:ReactCompilerCheck` - Manually refresh markers for the current file
- `:ReactCompilerHover` - Display a hover tooltip with detailed information about compilation status

## How It Works

The plugin works by:

1. Monitoring React/TypeScript files for changes
2. Running `babel-plugin-react-compiler` on the file content using Node.js
3. Parsing the compilation results to identify successful and failed optimizations
4. Displaying inlay hints (or virtual text as fallback) next to function definitions
5. Providing hover tooltips with detailed information about compilation status

## Troubleshooting

### "Could not load babel-plugin-react-compiler" error

Make sure `babel-plugin-react-compiler` is installed in your project:

```bash
npm install babel-plugin-react-compiler
```

Or install globally:

```bash
npm install -g babel-plugin-react-compiler
```

### Inlay hints not showing

If you're using Neovim < 0.10, the plugin will fall back to virtual text. Make sure inlay hints are enabled:

```lua
vim.lsp.inlay_hint.enable(true)
```

### Performance issues

The plugin caches compilation results to avoid redundant work. If you experience performance issues, you can disable automatic updates and use manual refresh instead:

```lua
require("react-compiler-marker").setup({
  enabled = false, -- Disable automatic updates
})

-- Use :ReactCompilerCheck to manually refresh
```

## Differences from VSCode Extension

- Uses Neovim's inlay hint API instead of decorations
- No "Preview Compiled Output" or "Fix with AI" features (yet)
- Simpler hover tooltips due to Neovim limitations
- No configuration UI (configured via Lua)

## Contributing

This is a port of the VSCode React Compiler Marker extension. Feel free to contribute improvements or report issues.
