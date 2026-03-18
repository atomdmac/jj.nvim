local utils = require("jj.utils")
local runner = require("jj.core.runner")

--- @class jj.picker.snacks
local M = {}

--- Displays the status files in a snacks picker
---@param opts  jj.picker.config
---@param files jj.picker.file[]
function M.status(opts, files)
	if not opts.snacks then
		return utils.notify("Snacks picker is `disabled`", vim.log.levels.INFO)
	end

	local snacks = require("snacks")

	local snacks_opts
	-- If its true we default to an empty table
	if opts.snacks == true then
		snacks_opts = {}
	else
		--- Otherwise we get the table from the config
		---@type table
		snacks_opts = opts.snacks
	end

	local merged_opts = vim.tbl_deep_extend("force", snacks_opts, {
		source = "jj",
		items = files,
		title = "JJ Status",
		preview = function(ctx)
			if ctx.item.file then
				snacks.picker.preview.cmd(ctx.item.diff_cmd, ctx, {})
			end
		end,
	})

	snacks.picker.pick(merged_opts)
end

local function format_jj_log(item, picker)
	local a = Snacks.picker.util.align
	local ret = {} ---@type snacks.picker.Highlight[]

	-- Add symbol (if available) and revision
	if item.symbol and item.symbol ~= "" then
		ret[#ret + 1] = { a(item.symbol, 1, { truncate = true }), "SnacksPickerGitMsg" }
	else
		ret[#ret + 1] = { "?", "SnacksPickerGitMsg" }
	end

	ret[#ret + 1] = { " " }

	local rev = item.rev or "unknown"
	-- INFO: This highlight is kind of a nice hack to avoid doing my own highlighs for the moment
	--- At some point i'll probably do mines
	ret[#ret + 1] = { a(rev, 4, { truncate = true }), "SnacksPickerGitBreaking" }
	if #rev >= 4 then
		ret[#ret + 1] = { " " }
	end

	if item.author then
		ret[#ret + 1] = { a(item.author, 8, { truncate = true }), "SnacksPcikerGitMsg" }
		if #item.author >= 8 then
			ret[#ret + 1] = { " " }
		end
	end

	if item.time then
		local year, month, day = item.time:match("(%d+)-(%d+)-(%d+)")
		local formatted = string.format("%s-%s-%s", year, day, month)
		ret[#ret + 1] = { a(formatted, 10), "SnacksPickerGitDate" }
		if #formatted >= 10 then
			ret[#ret + 1] = { " " }
		end
	end

	if item.commit_id then
		ret[#ret + 1] = { a(item.commit_id, 10, { truncate = true }), "SnacksPickerGitCommit" }
		if #item.commit_id >= 4 then
			ret[#ret + 1] = { " " }
		end
	end

	-- This comes from snacks git description formattedr
	local desc = item.description or ""
	local type, scope, breaking, body = desc:match("^(%S+)%s*(%(.-%))(!?):%s*(.*)$")

	if not type then
		type, breaking, body = desc:match("^(%S+)(!?):%s*(.*)$")
	end
	local msg_hl = "SnacksPickerGitMsg"
	if type and body then
		local dimmed = vim.tbl_contains({ "chore", "bot", "build", "ci", "style", "test" }, type)
		msg_hl = dimmed and "SnacksPickerDimmed" or "SnacksPickerGitMsg"
		ret[#ret + 1] = {
			type,
			breaking ~= "" and "SnacksPickerGitBreaking" or dimmed and "SnacksPickerBold" or "SnacksPickerGitType",
		}
		if scope and scope ~= "" then
			ret[#ret + 1] = { scope, "SnacksPickerGitScope" }
		end
		if breaking ~= "" then
			ret[#ret + 1] = { "!", "SnacksPickerGitBreaking" }
		end
		ret[#ret + 1] = { ":", "SnacksPickerDelim" }
		ret[#ret + 1] = { " " }
		desc = body
	end

	ret[#ret + 1] = { desc, msg_hl }
	return ret
end

---@param opts  jj.picker.config
---@param log_lines jj.picker.log_line[]
function M.file_log_history(opts, log_lines)
	if not opts.snacks then
		return utils.notify("Snacks picker is `disabled`", vim.log.levels.INFO)
	end

	local snacks = require("snacks")

	local snacks_opts
	-- If its true we default to an empty table
	if opts.snacks == true then
		snacks_opts = {}
	else
		--- Otherwise we get the table from the config
		---@type table
		snacks_opts = opts.snacks
	end

	local merged_opts = vim.tbl_deep_extend("force", snacks_opts, {
		source = "jj",
		items = log_lines,
		title = "JJ Log",
		format = format_jj_log,
		confirm = function(picker, item)
			picker:close()

			if not item or not item.rev then
				return
			end

			local _, ok = runner.execute_command(
				string.format("jj edit %s --ignore-immutable", item.rev),
				string.format("could not edit revision '%s'", item.rev)
			)

			if ok then
				utils.reload_changed_file_buffers()
				utils.notify(string.format("Editing revision `%s`", item.rev), vim.log.levels.INFO)
			end
		end,
		preview = function(ctx)
			if ctx.item.rev and ctx.item.diff_cmd then
				snacks.picker.preview.cmd(ctx.item.diff_cmd, ctx, {})
			end
		end,
	})

	snacks.picker.pick(merged_opts)
end

--- Format a bookmark item for the picker
---@param item table The bookmark item
---@param picker table The picker instance
---@return snacks.picker.Highlight[]
local function format_bookmark(item, picker)
	local a = Snacks.picker.util.align
	local ret = {} ---@type snacks.picker.Highlight[]

	-- Bookmark name
	local name = item.name or "unknown"
	ret[#ret + 1] = { a(name, 24, { truncate = true }), "SnacksPickerGitType" }
	if #name >= 24 then
		ret[#ret + 1] = { " " }
	end

	-- Change ID
	local change_id = item.change_id or ""
	if change_id ~= "" then
		ret[#ret + 1] = { a(change_id, 12, { truncate = true }), "SnacksPickerGitCommit" }
		if #change_id >= 12 then
			ret[#ret + 1] = { " " }
		end
	end

	-- Description
	local desc = item.description or ""
	if desc == "(no description set)" then
		ret[#ret + 1] = { desc, "SnacksPickerDimmed" }
	else
		ret[#ret + 1] = { desc, "SnacksPickerGitMsg" }
	end

	return ret
end

--- Handle editing a bookmark's change, with immutability awareness
---@param item table The selected bookmark item
local function handle_bookmark_edit(item)
	if not item or not item.change_id or item.change_id == "" then
		return
	end

	local name = item.name or item.change_id

	if utils.is_change_immutable(item.change_id) then
		vim.ui.select(
			{ "Abort", "Create new change on top", "Edit (ignore immutability)" },
			{ prompt = string.format("Change '%s' (%s) is immutable:", name, item.change_id) },
			function(choice)
				if choice == "Create new change on top" then
					local _, ok = runner.execute_command(
						string.format("jj new %s", item.change_id),
						string.format("Could not create new change on top of '%s'", name)
					)
					if ok then
						utils.reload_changed_file_buffers()
						utils.notify(
							string.format("Created new change on top of `%s` (%s)", name, item.change_id),
							vim.log.levels.INFO
						)
					end
				elseif choice == "Edit (ignore immutability)" then
					local _, ok = runner.execute_command(
						string.format("jj edit %s --ignore-immutable", item.change_id),
						string.format("Could not edit revision '%s'", name)
					)
					if ok then
						utils.reload_changed_file_buffers()
						utils.notify(
							string.format("Editing revision `%s` (%s) (immutability ignored)", name, item.change_id),
							vim.log.levels.INFO
						)
					end
				end
				-- "Abort" or nil (dismissed) → do nothing
			end
		)
	else
		local _, ok = runner.execute_command(
			string.format("jj edit %s", item.change_id),
			string.format("Could not edit revision '%s'", name)
		)
		if ok then
			utils.reload_changed_file_buffers()
			utils.notify(string.format("Editing revision `%s` (%s)", name, item.change_id), vim.log.levels.INFO)
		end
	end
end

--- Displays bookmarks in a snacks picker for editing
---@param opts jj.picker.config
---@param bookmarks jj.bookmark_detail[]
function M.bookmarks(opts, bookmarks)
	if not opts.snacks then
		return utils.notify("Snacks picker is `disabled`", vim.log.levels.INFO)
	end

	local snacks = require("snacks")

	local snacks_opts
	if opts.snacks == true then
		snacks_opts = {}
	else
		---@type table
		snacks_opts = opts.snacks
	end

	-- Build picker items from bookmark details
	local items = {}
	for _, bookmark in ipairs(bookmarks) do
		local desc_text = bookmark.description ~= "" and bookmark.description or "(no description set)"
		table.insert(items, {
			text = string.format("%s %s %s", bookmark.name, bookmark.change_id, desc_text),
			name = bookmark.name,
			change_id = bookmark.change_id,
			description = desc_text,
		})
	end

	local merged_opts = vim.tbl_deep_extend("force", snacks_opts, {
		source = "jj",
		items = items,
		title = "JJ Bookmarks",
		format = format_bookmark,
		confirm = function(picker, item)
			picker:close()
			handle_bookmark_edit(item)
		end,
	})

	snacks.picker.pick(merged_opts)
end

return M
