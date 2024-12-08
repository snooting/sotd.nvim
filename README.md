# SOTD.nvim

A Neovim plugin to format Shave of the Day (SOTD) posts for Reddit, Lemmy, Discord, etc. This plugin helps manage your den inventory and quickly generate formatted SOTD posts with your selected products.

## Features

- Manage your shaving den inventory in a JSON file
- Interactive product selection using Telescope
- Customizable number of pre-shave and post-shave products
- Blade use tracking for DE razors
- Optional title addition for SOTD posts
- Optional fragrance section

## Requirements

- Neovim >= 0.8.0
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [schemastore.nvim](https://github.com/b0o/schemastore.nvim)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "snooting/sotd.nvim",
    dependencies = {
        "nvim-telescope/telescope.nvim",
        "nvim-lua/plenary.nvim",
        "b0o/schemastore.nvim",
    },
    lazy = false,
    config = function()
        require("sotd").setup({
            -- Optional: override default configuration
            den_file = vim.fn.expand("~/.config/nvim/den.json"),
            log_file = vim.fn.expand("~/.config/nvim/sotd.log"),
            logging_enabled = false,
            preshave_number = 1,
            post_number = 4,
            include_fragrance = false, -- Optional: enable fragrance section
        })
    end,
    -- Optional: Add keymaps
    keys = {
        { "<leader>sc", "<cmd>SOTDCreate<cr>", desc = "Create SOTD Post" },
    },
}
```

## Configuration

The plugin uses a JSON file to store your den inventory. Create a file at `~/.config/nvim/den.json` (or your preferred location) with the following structure:

```json
{
  "brush": [
    {
      "name": "Zenith B21 boar",
      "status": "In Den",
      "link": "https://example.com/brush-link",
      "daily_post_link": "[Zenith - B21 boar](https://imgur.com/a/zenith-b21-boar-oP0sLsA)"
    }
  ],
  "blade": [
    {
      "name": "Astra Superior Platinum",
      "number_uses": "0"
    }
  ],
  "razor": [
    {
      "link": "https://getrockwell.com/products/rockwell-6c-double-edge-safety-razor",
      "daily_post_link": "Rockwell - 6C",
      "type": "DE",
      "status": "In Den",
      "name": "Rockwell - 6C"
    }
  ],
  "lather": [
    {
      "name": "Stirling Arkadia",
      "daily_post_link": "Stirling - Arkadia",
      "status": "In Den",
      "link": "https://www.stirlingsoap.com/products/arkadia-shave-soap"
    }
  ],
  "post": [
    {
      "name": "Stirling - Arkadia",
      "daily_post_link": "Stirling - Arkadia AS splash",
      "status": "In Den",
      "link": ""
    }
  ],
  "fragrance": [
    {
      "name": "Stirling Arkadia EdT",
      "daily_post_link": "Stirling - Arkadia EdT",
      "status": "In Den",
      "link": ""
    }
  ]
}
```

### Default Configuration

```lua
{
    -- Path to your den file (will be created if it doesn't exist)
    den_file = vim.fn.expand("~/.config/nvim/den.json"),
    -- Path to your log file (optional)
    log_file = vim.fn.expand("~/.config/nvim/sotd.log"),
    -- Whether to enable logging
    logging_enabled = false,
    -- Number of pre-shave products to prompt for
    preshave_number = 1,
    -- Number of post-shave products to prompt for
    postshave_number = 4,
    -- Whether to include fragrance section
    include_fragrance = false,
}
```

## Usage

1. Create your den inventory file following the structure above
2. Run `:SOTDCreate` in Neovim
3. Enter an optional title when prompted
4. Select products from your den using Telescope
5. The plugin will create a new buffer with your formatted SOTD post

The output will look something like this:

```markdown
**Thursday, November 7, 2024: Morning Shave**

- **Brush:** [Zenith - B21 boar](https://imgur.com/a/zenith-b21-boar-oP0sLsA)
- **Razor:** Rockwell - 6C
- **Blade:** Gillette - Perma-Sharp (4)
- **Lather:** Stirling - Arkadia
- **Post Shave:** Nivea - Sensitive After Shave Balm
- **Post Shave:** Stirling - Arkadia AS splash
- **Frag** Stirling - Arkadia EdT

---

~Shared via [Neovim](https://neovim.io/) & [sotd.nvim](https://github.com/snooting/sotd.nvim)~
```

## Commands

- `:SOTDCreate` - Start the SOTD post creation process

## Keymaps

The plugin doesn't set any keymaps by default. You can add your own in your Neovim configuration:

```lua
vim.keymap.set('n', '<leader>sc', '<cmd>SOTDCreate<cr>', { desc = 'Create SOTD Post' })
```

## Debugging

If you encounter issues, you can enable logging in the configuration:

```lua
require('sotd').setup({
    logging_enabled = true,
    log_file = vim.fn.expand("~/.config/nvim/sotd.log"),
})
```

The log file will contain detailed information about the plugin's operations.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - See [LICENSE](LICENSE) for more information.
