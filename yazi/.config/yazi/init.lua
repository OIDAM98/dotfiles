require("full-border"):setup {
	-- Available values: "plain", "rounded"
	set = "rounded",
}

require("git"):setup()
require("duckdb"):setup({
	mode = "standard",
	cache_size = 1000
})
