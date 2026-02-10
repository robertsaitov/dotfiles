return {
	"obsidian-nvim/obsidian.nvim",
	version = "*",
	ft = "markdown",
	opts = {
        legacy_commands = false,
		workspaces = {
			{
				name = "regular-notes",
				path = "~/personal/obsidian-notes/",
				overrides = {
					notes_subdir = "inbox",
				},
			},
		},
		completion = {
            blink = true,
			min_chars = 2,
		},
		new_notes_location = "notes_subdir",
		link = {
			wiki = function(opts)
				if opts.id == nil then
					return string.format("[[%s]]", opts.label)
				elseif opts.label ~= opts.id then
					return string.format("[[%s|%s]]", opts.id, opts.label)
				else
					return string.format("[[%s]]", opts.id)
				end
			end,
		},
		frontmatter = {
			func = function(note)
				local out = { id = note.id, aliases = note.aliases, tags = note.tags }
				if note.metadata ~= nil and not vim.tbl_isempty(note.metadata) then
					for k, v in pairs(note.metadata) do
						out[k] = v
					end
				end
				return out
			end,
		},
		note_id_func = function(title)
			local suffix = ""
			if title ~= nil then
				suffix = title:gsub(" ", "-"):gsub("[^A-Za-z0-9-]", ""):lower()
			else
				for _ = 1, 4 do
					suffix = suffix .. string.char(math.random(65, 90))
				end
			end
			return tostring(os.time()) .. "-" .. suffix
		end,
		templates = {
			subdir = "assets/templates",
			date_format = "%Y-%m-%d-%a",
			time_format = "%H:%M",
		},
		ui = {
			enable = true,
			checkbox = {},
			bullets = {},
			external_link_icon = {},
		},
	},
}
