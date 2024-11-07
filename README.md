# SOTD.nvim

A Neovim plugin to format Shave of the Day (SOTD) posts for Reddit, Lemmy, Discord, etc. This plugin helps manage your den inventory and quickly generate formatted SOTD posts with your selected products.

## Features

- Manage your shaving den inventory in a JSON file
- Interactive product selection using Telescope
- Markdown-formatted output with optional links
- Customizable number of pre-shave and post-shave products
- Optional title addition for SOTD posts

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
    config = function()
        require("sotd").setup({
            -- Optional: override default configuration
            den_file = vim.fn.expand("~/.config/nvim/den.json"),
            log_file = vim.fn.expand("~/.config/nvim/sotd.log"),
            logging_enabled = false,
            preshave_number = 1,
            postshave_number = 4,
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
      "name": "Semogue C3 Galahad Horse 🐎",
      "status": "In Den",
      "link": "https://example.com/brush-link",
      "daily_post_link": "[Semogue C3 Galahad Horse 🐎](https://example.com/brush-link)"
    }
  ],
  "preshave": [
    {
      "name": "Proraso Green Preshave",
      "status": "In Den",
      "link": "https://example.com/preshave-link",
      "daily_post_link": "[Proraso Green Preshave](https://example.com/preshave-link)"
    }
  ],
  "razor": [
    {
      "name": "Mühle R41",
      "type": "DE", // Razors with type "DE" will trigger blade selection prompt
      "status": "In Den",
      "link": "https://example.com/razor-link",
      "daily_post_link": "[Mühle R41](https://example.com/razor-link)"
    },
    {
      "name": "Thiers-Issard 188 7/8 'Coq et Renard'",
      "type": "Straight",
      "status": "In Den",
      "link": "https://www.artdubarbier.com/8094-large_default/rasoir-thiers-issard-188-78-soleil-ebene.jpg",
      "daily_post_link": "[Thiers-Issard 188 7/8 'Coq et Renard'](https://www.artdubarbier.com/8094-large_default/rasoir-thiers-issard-188-78-soleil-ebene.jpg)"
    }
  ],
  "blade": [
    {
      "name": "Astra Superior Platinum",
      "number_uses": "14"
    },
    {
      "name": "Feather",
      "number_uses": "0"
    },
    {
      "name": "Gillette Silver Blue",
      "number_uses": "0"
    }
  ],
  "lather": [
    {
      "name": "Haslinger Schafmilch",
      "status": "In Den",
      "link": "https://example.com/soap-link",
      "daily_post_link": "[Haslinger Schafmilch](https://example.com/soap-link)"
    }
  ],
  "postshave": [
    {
      "name": "Nivea Sensitive Post Shave Balm",
      "status": "In Den",
      "link": "https://example.com/aftershave-link",
      "daily_post_link": "[Nivea Sensitive Post Shave Balm](https://example.com/aftershave-link)"
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

- **Preshave:** [Proraso Green Preshave](https://example.com/preshave-link)
- **Brush:** [Semogue C3 Galahad Horse 🐎](https://example.com/brush-link)
- **Razor:** [Mühle R41](https://example.com/razor-link)
- **Lather:** [Haslinger Schafmilch](https://example.com/soap-link)
- **Postshave:** [Nivea Sensitive Post Shave Balm](https://example.com/aftershave-link)

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
