# FloatBar.nvim

A modern, **toggleable floating terminal** for Neovim with **persistent buffers**, **theme support**, and **transparent windows**.  
Perfect for users of **Kitty**, **Alacritty**, or any true-color terminal.

---

## Features

- Toggleable floating terminal with `<space>tt`
- Persistent buffer after closing
- Transparent and theme-aware (supports TokyoNight and other true-color themes)
- Semi-transparent (`winblend`) adjustable
- Customizable width, height, and border
- Works in **terminal mode** as well
- Send commands programmatically with `require("floatbar").send("command")`

---

## Installation

### Using Lazy.nvim

```lua
{
  "Redooyyy/floatbar-nvim",
  config = function()
    require("floatbar").setup({
      width = 0.8,      -- Floating window width (percentage)
      height = 0.8,     -- Floating window height (percentage)
      winblend = 20,    -- Transparency (0-100)
      border = "rounded" -- Window border style
    })
  end,
}
```

### Using Packer.nvim

```lua
use {
  "Redooyyy/floatbar-nvim",
  config = function()
    require("floatbar").setup({
      width = 0.8,
      height = 0.8,
      winblend = 20,
      border = "rounded",
    })
  end
}
```

### Usage

```
Toggle terminal: <space>tt
```

### Send command programmatically:

#### require("floatbar").send("ls -la")

Terminal buffer persists after closing

Works in both normal and terminal mode

### Configuration

```lua
require("floatbar").setup({
    width = 0.7,       -- 70% of screen width
    height = 0.7,      -- 70% of screen height
    winblend = 30,     -- more transparent
    border = "double", -- other options: single, rounded, solid
})

```

### Keymaps

Mode Key Action
Normal <space>tt Toggle floating terminal

```
Terminal	<space>tt	Toggle floating terminal
```

## Notes

Make sure vim.o.termguicolors = true is enabled in your config.

Transparent floating terminals work best with true-color terminals like Kitty, Alacritty, or iTerm2.

Colors inherit your Neovim theme (tested with TokyoNight).
