local M = {}
local sqlite = require("sqlite.db")

local config = {}

local function debug_log(...) end

local migrations = {
	{
		version = 1,
		up = [[
            CREATE TABLE IF NOT EXISTS shaves (
                id INTEGER PRIMARY KEY,
                date TEXT NOT NULL,
                razor TEXT NOT NULL,
                blade TEXT NOT NULL,
                blade_uses INTEGER,
                pre_shave TEXT,
                soap TEXT,
                brush TEXT,
                post_shave_1 TEXT,
                post_shave_2 TEXT,
                post_shave_3 TEXT,
                fragrance TEXT,
                notes TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS schema_version(version INTEGER PRIMARY KEY);

            INSERT OR IGNORE INTO schema_version (version) VALUES (1);

        ]],
	},
}

local function run_migrations(db)
	-- First check if schema_version exists
	local version = 0

	if db:exists("SELECT 1 FROM sqlite_master WHERE type='table' AND name='schema_version'") then
		version = db:first_col("SELECT version FROM schema_version ORDER BY version DESC LIMIT 1") or 0
	end

	-- Execute migrations in order
	for _, migration in ipairs(migrations) do
		if migration.version > version then
			local ok, err = db:execute(migration.up)
			if not ok then
				error("Migration " .. migration.version .. " failed: " .. err)
			end

			-- Update version after successful migration
			db:execute("UPDATE schema_version SET version = " .. migration.version)

			vim.notify("Database migrated to version " .. migration.version, vim.log.levels.INFO)
		end
	end
end

local function init_db()
	local db_path = config.db_path or vim.fn.expand("~/.config/nvim/sotd.db")

	-- Create proper SQLite connection
	local db, err = sqlite:open(db_path)

	if not db then
		vim.notify("Failed to open database: " .. (err or "unknown error"), vim.log.levels.ERROR)
		return nil
	end

	-- Enable foreign key support
	db:execute("PRAGMA foreign_keys = ON;")

	return db
end

-- Configuration with defaults
M.setup = function(opts)
	config = vim.tbl_deep_extend("force", {
		db_path = vim.fn.expand("~/.config/nvim/sotd.db"),
		-- other config options
	}, opts or {})

	-- Initialize database
	M.db = init_db()

	if not M.db or M.db:isclose() then
		vim.notify("Failed to initialize database connection", vim.log.levels.ERROR)
		return
	end

	local ok, err = pcall(run_migrations, M.db)
	if not ok then
		vim.notify("Migration failed: " .. err, vim.log.levels.ERROR)
		M.db:close()
		return
	end

	-- Create commands
	vim.api.nvim_create_user_command("SOTDCreate", function()
		M.create_sotd()
	end, { desc = "Create new Shave of the Day entry" })

	-- vim.api.nvim_create_user_command("SOTDStats", function(opts)
	-- 	M.show_stats(opts.args)
	-- end, {
	-- 	nargs = "?",
	-- 	complete = function()
	-- 		return { "blades", "soaps", "razors", "posts" }
	-- 	end,
	-- 	desc = "Show shaving statistics",
	-- })
end

M.save_den = function(data)
	debug_log("Saving den file to:", config.den_file)

	-- Encode the data to JSON
	local json_content = vim.json.encode(data)

	-- Write the JSON to the file
	local f = io.open(config.den_file, "w")
	if not f then
		debug_log("ERROR: Could not open den file for writing")
		vim.notify("Could not write to den file: " .. config.den_file, vim.log.levels.ERROR)
		return false
	end

	f:write(json_content)
	f:close()

	debug_log("Successfully saved den data")
	return true
end

-- Data handling
M.load_den = function()
	debug_log("Loading den file from:", config.den_file)

	local f = io.open(config.den_file, "r")
	if not f then
		debug_log("ERROR: Could not open den file")
		vim.notify("Could not read den file: " .. config.den_file, vim.log.levels.ERROR)
		return {}
	end

	local content = f:read("*all")

	f:close()

	debug_log("Den file content length:", #content)

	local ok, data = pcall(vim.json.decode, content)

	if not ok then
		debug_log("ERROR: Could not parse JSON:", data)
		vim.notify("Could not parse den file: " .. data, vim.log.levels.ERROR)
		return {}
	end

	debug_log("Loaded den data:", data)

	return data
end

vim.g.current_razor = nil

M.choose_product = function(product_type, callback, filter_fn)
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")

	local den = M.load_den()
	if not den or not den[product_type] then
		vim.notify("No " .. product_type .. " found in den file", vim.log.levels.ERROR)
		callback(nil)
		return
	end

	local items = den[product_type]
	if filter_fn then
		items = vim.tbl_filter(filter_fn, items)
	elseif product_type == "blade" and vim.g.current_razor then
		-- Filter blades to only show those for current razor
		items = vim.tbl_filter(function(item)
			return item.razor ~= "" and item.razor == vim.g.current_razor.name
		end, items)
	elseif product_type ~= "blade" then
		items = vim.tbl_filter(function(item)
			return item.status == "In Den"
		end, items)
	end

	if #items == 0 then
		local msg = product_type == "blade" and "No blades found in den file"
			or "No '" .. product_type .. "' items found with 'In Den' status"

		vim.notify(msg, vim.log.levels.ERROR)

		callback(nil)
		return
	end

	pickers
		.new({}, {
			prompt_title = "Choose " .. product_type,
			finder = finders.new_table({
				results = items,
				entry_maker = function(entry)
					local display = entry.name

					if product_type == "blade" then
						display = string.format("%s (%s uses)", display, entry.number_uses or "0")
					end

					return {
						value = entry,
						display = display,
						ordinal = display,
					}
				end,
			}),
			sorter = conf.generic_sorter({}),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()

					actions.close(prompt_bufnr)

					if product_type == "blade" then
						local current_razor = vim.g.current_razor

						if not current_razor then
							vim.notify("No razor selected before blade selection", vim.log.levels.ERROR)
							callback(nil)
							return
						end

						local uses = tonumber(selection.value.number_uses) or 0

						local choices = {
							"New blade (reset count to 1)",
							"Increment existing blade count",
							"Cancel selection",
						}

						local choice =
							vim.fn.confirm("Is this a new blade or existing blade?", table.concat(choices, "\n"), 1)

						if choice == 1 then
							-- New blade - reset count to 1
							selection.value.number_uses = "1"
						elseif choice == 2 then
							-- Existing blade - increment count
							selection.value.number_uses = tostring(uses + 1)
						else
							-- Cancel
							callback(nil)
							return
						end

						-- Save the updated den file
						for i, blade in ipairs(den.blade) do
							if blade.name == selection.value.name and blade.razor == current_razor.name then
								den.blade[i].number_uses = selection.value.number_uses
								break
							end
						end
						M.save_den(den)

						selection.value.daily_post_link =
							string.format("%s (%s)", selection.value.name, selection.value.number_uses)
					end

					callback(selection.value)
				end)
				return true
			end,
		})
		:find()
end

-- Async product selection chain
local function select_products(products, current_index, results, final_callback)
	if current_index > #products then
		final_callback(results)
		return
	end

	local product = products[current_index]
	local product_type, count = unpack(product)

	local function handle_product(index)
		if index > count then
			-- Move to next product type
			select_products(products, current_index + 1, results, final_callback)
			return
		end

		M.choose_product(product_type, function(selected)
			if selected then
				table.insert(results, {
					type = product_type,
					item = selected,
				})

				-- If this is a DE razor, prompt for blade selection
				if product_type == "razor" and (selected.type == "DE" or selected.type == "SE") then
					vim.g.current_razor = selected

					M.choose_product("blade", function(blade)
						if blade then
							table.insert(results, {
								type = "blade",
								item = blade,
							})
						end
						handle_product(index + 1)
					end)
				else
					handle_product(index + 1)
				end
			else
				handle_product(index + 1)
			end
		end)
	end

	handle_product(1)
end

M.create_sotd = function()
	if not M.db or M.db:isclose() then
		vim.notify("Database connection not available", vim.log.levels.ERROR)
		return
	end

	local selections = {
		razor = nil,
		blade = nil,
		lather = nil,
		brush = nil,
		post = {},
		fragrance = nil,
	}

	local function select_next_product(products, index, callback)
		if index > #products then
			callback()
			return
		end

		local product_type, count = unpack(products[index])

		local function handle_selection(selected, num_selected)
			if selected then
				if product_type == "post" then
					for i = 1, count do
						selections.post[i] = selections.post[i] or {}
						if selected[i] then
							selections.post[i] = selected[i].item
						end
					end
				else
					selections[product_type] = selected.item
					if product_type == "razor" then
						vim.g.current_razor = selected.item
					end
				end
			end
			select_next_product(products, index + 1, callback)
		end

		if product_type == "post" then
			-- Special handling for multiple post-shave products
			local posts_selected = 0
			local post_results = {}

			local function select_post(n)
				if n > count then
					handle_selection(post_results)
					return
				end

				M.choose_product("post", function(selected)
					if selected then
						post_results[n] = selected
						posts_selected = posts_selected + 1
					end
					select_post(n + 1)
				end)
			end

			select_post(1)
		else
			M.choose_product(product_type, function(selected)
				handle_selection(selected)
			end)
		end
	end

	local products = {
		{ "preshave", config.preshave_number },
		{ "brush", 1 },
		{ "razor", 1 },
		{ "blade", 1 },
		{ "lather", 1 },
		{ "post", config.post_number },
	}

	if config.include_fragrance then
		table.insert(products, { "fragrance", 1 })
	end

	select_next_product(products, 1, function()
		local params = {
			date = os.date("%Y-%m-%d"),
			razor = selections.razor and selections.razor.name or "",
			blade = selections.blade and selections.blade.name or "",
			blade_uses = selections.blade and tonumber(selections.blade.number_uses) or 0,
			soap = selections.lather and selections.lather.name or "",
			brush = selections.brush and selections.brush.name or "",
			post_1 = selections.post[1] and selections.post[1].name or "",
			post_2 = selections.post[2] and selections.post[2].name or "",
			post_3 = selections.post[3] and selections.post[3].name or "",
			fragrance = selections.fragrance and selections.fragrance.name or "",
		}

		print("selections", params)

		M.db:insert("shaves", {
			date = params.date,
			razor = params.razor,
			blade = params.blade,
			blade_uses = params.blade_uses,
			soap = params.soap,
			brush = params.brush,
			post_shave_1 = params.post_1,
			post_shave_2 = params.post_2,
			post_shave_3 = params.post_3,
			fragrance = params.fragrance,
		})

		-- Create buffer with SOTD summary
		local lines = {
			"# Shave of the Day - " .. os.date("%A, %B %d, %Y"),
			"",
			"## Products Used",
			"- Razor: " .. (params.razor ~= "" and params.razor or "N/A"),
			"- Blade: " .. (params.blade ~= "" and params.blade .. " (Use #" .. params.blade_uses .. ")" or "N/A"),
			"- Brush: " .. (params.brush ~= "" and params.brush or "N/A"),
			"- Soap: " .. (params.soap ~= "" and params.soap or "N/A"),
			"- Post Shave: " .. table.concat(
				vim.tbl_filter(function(v)
					return v ~= ""
				end, {
					params.post_1,
					params.post_2,
					params.post_3,
				}),
				", "
			),
		}

		if config.include_fragrance and params.fragrance ~= "" then
			table.insert(lines, "- Fragrance: " .. params.fragrance)
		end

		local buf = vim.api.nvim_create_buf(true, true)
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		vim.api.nvim_command("buffer " .. buf)
	end)
end

return M
