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
		postshave_number = 4,
	}, opts or {})
	debug_log("Final config:", M.config)
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

M.choose_product = function(product_type, callback)
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

	local items = vim.tbl_filter(function(item)
		return item.status == "In Den"
	end, den[product_type])

	if #items == 0 then
		vim.notify("No '" .. product_type .. "' items found with 'In Den' status", vim.log.levels.ERROR)
		callback(nil)
		return
	end

	pickers
		.new({}, {
			prompt_title = "Choose " .. product_type,
			finder = finders.new_table({
				results = items,
				entry_maker = function(entry)
					return {
						value = entry,
						display = entry.name,
						ordinal = entry.name,
					}
				end,
			}),
			sorter = conf.generic_sorter({}),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
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
			end
			handle_product(index + 1)
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
	-- TODO: add other product types?
	local products = {
		{ "preshave", M.config.preshave_number },
		{ "brush", 1 },
		{ "razor", 1 },
		{ "lather", 1 },
		{ "postshave", M.config.postshave_number },
	}

	-- Start the selection chain
	select_products(products, 1, {}, function(selections)
		local output_lines = { current_date, "" }

		-- Sort selections by original product order
		local product_order = {}
		for i, product in ipairs(products) do
			product_order[product[1]] = i
		end

		table.sort(selections, function(a, b)
			return product_order[a.type] < product_order[b.type]
		end)

		-- Process selections
		for _, selection in ipairs(selections) do
			table.insert(
				output_lines,
				string.format("* **%s:** %s", selection.type:gsub("^%l", string.upper), selection.item.daily_post_link)
			)
		end

		-- Add footer
		table.insert(output_lines, "")
		table.insert(output_lines, "---")
		table.insert(output_lines, "")
		table.insert(
			output_lines,
			"~Shared via [Neovim](https://neovim.io/) & [sotd.nvim](https://github.com/snooting/sotd.nvim)~"
		)

		-- Set buffer content
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, output_lines)
		debug_log("Final buffer contents:", output_lines)
	end)
end

return M
