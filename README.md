# flutter-deps.nvim

A Neovim plugin to **quickly search and add Flutter dependencies** from [pub.dev](https://pub.dev) directly into your `pubspec.yaml` using Telescope-style fuzzy selection.

No more manual copy-pasting — just type, select, and add dependencies instantly.

---

## Features

- Search for any Flutter/Dart dependency from pub.dev.
- Fuzzy search using Telescope.
- Automatically adds the selected dependency to your `pubspec.yaml`.
- Optional floating window interface for smooth selection.
- Works asynchronously — non-blocking while typing.

---

## Installation

Using **lazy.nvim**:

```lua
{
  "Redooyyy/flutter-deps.nvim",
  dependencies = { "nvim-lua/plenary.nvim", "nvim-telescope/telescope.nvim" },
  config = function()
    require("flutter-deps").setup()
  end
}
```

## Usage

### Command

```vim
:FlutterDeps
```

### Lua API

```lua
require("flutter-deps").open()  -- Opens the dependency picker
```

### Keymap Example

```lua
-- Example: Ctrl+d to open Flutter dependency picker
vim.keymap.set('n', '<space>'pd, function()
  require("flutter-deps").open()
end, { noremap = true, silent = true, desc = "Open Flutter Dependency Picker" })
```

## Example Workflow

1. Press your configured key (<C-d> in the example).

2. Type the dependency name, e.g., provider.

3. Select the version from the list.

4. The plugin automatically inserts it into pubspec.yaml.

## Configuration

You can optionally pass settings to customize the floating window:

```lua
require("flutter-deps").setup({
  width = 0.7,         -- floating window width (0.0-1.0)
  height = 0.7,        -- floating window height (0.0-1.0)
  border = "rounded",  -- border style: "single", "double", "rounded", "solid", "shadow"
  winblend = 0,        -- transparency (0-100)
})
```

### Defaults:

```lua
{
  width = 0.7,
  height = 0.7,
  border = "rounded",
  winblend = 0,
}
```

## Dependencies

    nvim-lua/plenary.nvim

    nvim-telescope/telescope.nvim

## Contributing

Contributions, bug reports, and suggestions are welcome!

1. Fork the repository.

2. Create your feature branch: `git checkout -b feature/my-feature`

3. Commit your changes: `git commit -am 'Add some feature'`

4. Push to the branch: `git push origin feature/my-feature`

5. Open a Pull Request.
