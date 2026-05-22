

# flutter-deps.nvim

A Neovim plugin to **search and add Flutter/Dart dependencies** from [pub.dev](https://pub.dev) directly into your `pubspec.yaml` — without leaving your editor.

No more alt-tabbing to a browser, copying version strings, and manually editing YAML. Just search, select, and go.

---

## Demo

```
:FlutterDepsAdd
```

Type `firebase_auth` → results appear instantly → press `Enter` to add the latest version, or `Tab` to pick a specific version.

### Default Latest version

https://github.com/user-attachments/assets/f577f654-d728-4aae-b94f-2f9627e3a890


### Select specific version

https://github.com/user-attachments/assets/7a99a525-4dbf-47a0-868c-599e84656cdc

---

## Features

- 🔍 **Fuzzy search** pub.dev packages via Telescope
- ⚡ **Non-blocking** — async search, never freezes your editor
- 📦 **Latest version** added automatically on `Enter`
- 🔖 **Version picker** on `Tab` — choose any historical version
- ✍️ **Auto-writes** to `pubspec.yaml` and runs `flutter pub get`
- 💾 **Caches** results so repeated lookups are instant

---

## Requirements

- [Neovim](https://neovim.io/) `>= 0.8`
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- `curl` and `jq` available in your `$PATH`

---

## Installation

### lazy.nvim

```lua
{
  "Redooyyy/flutter-deps.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
  },
  config = function()
    require("flutter_deps").setup()
  end,
}
```

### packer.nvim

```lua
use {
  "Redooyyy/flutter-deps.nvim",
  requires = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
  },
  config = function()
    require("flutter_deps").setup()
  end,
}
```

---

## Setup

Call `setup()` once in your config. No required options — it works out of the box.

```lua
require("flutter_deps").setup()
```

### Options

```lua
require("flutter_deps").setup({
  keymap = "<leader>pd",  -- default keymap (not yet auto-bound, see Usage)
})
```

---

## Usage

### Command

```vim
:FlutterDepsAdd
```

### Recommended Keymap

Add this to your Neovim config:

```lua
vim.keymap.set("n", "<leader>pd", function()
  require("flutter_deps").add_dependency()
end, { noremap = true, silent = true, desc = "Add Flutter dependency" })
```

### Workflow

| Step | Action              | Result                                                  |
| ---- | ------------------- | ------------------------------------------------------- |
| 1    | Open the picker     | `:FlutterDepsAdd` or your keymap                        |
| 2    | Type a package name | Results stream in from pub.dev                          |
| 3    | Press `Enter`       | Adds the **latest version** to `pubspec.yaml`           |
| 3    | Press `Tab` instead | Opens a **version picker** to choose a specific version |
| 4    | Done                | `flutter pub get` runs automatically in the background  |

---

## How It Works

1. As you type, the plugin queries `https://pub.dev/api/search` and streams results into Telescope asynchronously.
2. When you select a package, it fetches the full package info from `https://pub.dev/api/packages/<name>` using `jq` to extract version data.
3. The selected dependency is written into the `dependencies:` block of your `pubspec.yaml`.
4. `flutter pub get` is launched in the background — no extra step needed.

Results are cached per session, so selecting the same package twice is instant.

---

## Project Structure

```
flutter-deps.nvim/
├── lua/
│   └── flutter_deps/
│       ├── init.lua          # Core plugin logic & Telescope UI
│       ├── writer.lua        # pubspec.yaml writer
│       └── finder.lua        # pub.dev search (plenary.job)
└── plugin/
    └── flutter_deps.lua      # Auto-loads the FlutterDepsAdd command
```

---

## Troubleshooting

**No results showing up**

- Make sure `jq` is installed: `which jq`
- Make sure `curl` is installed: `which curl`
- Check you have an active internet connection

**"Could not fetch version"**

- Verify the package name is correct (must match pub.dev exactly, e.g. `firebase_auth` not `firebase auth`)
- Try running manually: `curl -s 'https://pub.dev/api/packages/firebase_auth' | jq '.latest.version'`

**`pubspec.yaml` not found**

- Make sure Neovim is opened from your Flutter project root (the directory containing `pubspec.yaml`)

---

## Contributing

Contributions, bug reports, and feature requests are welcome!

1. Fork the repository
2. Create your branch: `git checkout -b feature/my-feature`
3. Commit your changes: `git commit -am 'Add my feature'`
4. Push to the branch: `git push origin feature/my-feature`
5. Open a Pull Request

---

## License

MIT — see [LICENSE](LICENSE) for details.
