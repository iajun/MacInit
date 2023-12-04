require("telescope").load_extension("project")
require("telescope").load_extension("dap")
require("telescope").load_extension("frecency")

lvim.builtin.telescope.defaults.file_ignore_patterns = {
	".git/",
	"node_modules",
	".cache",
	"dist",
}
