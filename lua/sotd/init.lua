local M = {}

local function debug_log(...)
	local debug_file = "/tmp/sotd_debug.log"

	local f = io.open(debug_file, "a")
	if f then
		local args = { ... }

		local str_args = {}

		for i, arg in ipairs(args) do
			str_args[i] = type(arg) == "table" and vim.inspect(arg) or tostring(arg)
		end

		local timestamp = os.date("%Y-%m-%d %H:%M:%S")

		f:write(string.format("[%s] %s\n", timestamp, table.concat(str_args, " ")))

		f:close()
	end
end

-- Configuration with defaults
M.setup = function(opts)
	debug_log("Setting up plugin with opts:", opts)

	M.config = vim.tbl_deep_extend("force", {
		den_file = vim.fn.expand("~/.config/nvim/den.json"),
		log_file = vim.fn.expand("~/.config/nvim/sotd.log"),
		logging_enabled = false,
		preshave_number = 1,
		post_number = 4,
	}, opts or {})

	debug_log("Final config:", M.config)
end

M.save_den = function(data)
	debug_log("Saving den file to:", M.config.den_file)

	local f = io.open(M.config.den_file, "w")
	if not f then
		debug_log("ERROR: Could not open den file for writing")
		vim.notify("Could not write to den file: " .. M.config.den_file, vim.log.levels.ERROR)
		return false
	end

	local ok, encoded = pcall(vim.json.encode, data)
	if not ok then
		debug_log("ERROR: Could not encode JSON:", encoded)
		vim.notify("Could not encode den data: " .. encoded, vim.log.levels.ERROR)
		f:close()
		return false
	end

	f:write(encoded)

	f:close()
	debug_log("Successfully saved den data")
	return true
end

-- Data handling
M.load_den = function()
	debug_log("Loading den file from:", M.config.den_file)

	local f = io.open(M.config.den_file, "r")
	if not f then
		debug_log("ERROR: Could not open den file")
		vim.notify("Could not read den file: " .. M.config.den_file, vim.log.levels.ERROR)
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
					if product_type == "blade" and entry.number_uses then
						display = display .. " (" .. entry.number_uses .. " uses)"
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
							if blade.name == selection.value.name then
								den.blade[i].number_uses = selection.value.number_uses
								break
							end
						end
						M.save_den(den)
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
				if product_type == "razor" and selected.type == "DE" then
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
	debug_log("Starting SOTD creation")

	-- Get title first
	local current_date = os.date("**%A, %B %d, %Y**")
	local title = vim.fn.input("Enter SOTD title (optional): ")
	if title ~= "" then
		current_date = current_date:gsub("%*%*$", ": " .. title .. "**")
	end

	-- Create buffer first
	local buf = vim.api.nvim_create_buf(true, true)
	vim.api.nvim_buf_set_option(buf, "buftype", "")
	vim.api.nvim_command("buffer " .. buf)

	-- Product types to prompt for
	local products = {
		{ "preshave", M.config.preshave_number },
		{ "brush", 1 },
		{ "razor", 1 },
		{ "lather", 1 },
		{ "post", M.config.post_number },
	}

	-- Start the selection chain
	select_products(products, 1, {}, function(selections)
		local output_lines = { current_date, "" }

		-- Sort selections by original product order and handle blade placement
		local product_order = {
			preshave = 1,
			brush = 2,
			razor = 3,
			blade = 3.5, -- Position blade right after razor
			lather = 4,
			post = 5,
		}

		table.sort(selections, function(a, b)
			return product_order[a.type] < product_order[b.type]
		end)

		-- Process selections
		for _, selection in ipairs(selections) do
			local formatted_type = selection.type:gsub("^%l", string.upper)
			local item_text = selection.item.daily_post_link

			-- Special handling for blade display
			if selection.type == "blade" then
				item_text = selection.item.daily_post_link
					or (selection.item.name .. " (" .. selection.item.number_uses .. ")")
			end

			table.insert(output_lines, string.format("* **%s:** %s", formatted_type, item_text))
		end

		-- Add footer
		table.insert(output_lines, "")
		table.insert(output_lines, "---")
		table.insert(output_lines, "")
		table.insert(
			output_lines,
			"🍳 Created with [Neovim](https://neovim.io/) & [sotd.nvim](https://github.com/snooting/sotd.nvim) 🍳"
		)

		-- Set buffer content
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, output_lines)
		debug_log("Final buffer contents:", output_lines)
	end)
end

return M
