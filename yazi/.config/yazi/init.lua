require("full-border"):setup {
	-- Available values: ui.Border.PLAIN, ui.Border.ROUNDED
	type = ui.Border.ROUNDED,
}

require("git"):setup()
require("duckdb"):setup({
	mode = "standard",
	cache_size = 1000
})
