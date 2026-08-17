local wezterm = require("wezterm")

local config = wezterm.config_builder()

config.initial_cols = 120
config.initial_rows = 28

config.font_size = 14.0
config.font = wezterm.font_with_fallback({
	{
		family = "FiraCode Nerd Font",
		weight = "Medium",
		harfbuzz_features = { "calt=0", "clig=0", "liga=0" },
	},
	{
		family = "LigaSFMonoNerdFont",
		weight = "Medium",
		harfbuzz_features = { "calt=0", "clig=0", "liga=0" },
	},
	{
		family = "JetBrains Mono",
		weight = "Medium",
	},
	{ family = "Noto Color Emoji", assume_emoji_presentation = true },
})
-- matugen-generierte Farben aus colors.lua laden
-- (wird bei jedem wallpaper-Wechsel von matugen neu geschrieben)
config.automatically_reload_config = true
local colors_path = wezterm.config_dir .. "/colors.lua"
wezterm.add_to_config_reload_watch_list(colors_path)
local ok, palette = pcall(dofile, colors_path)
if ok and type(palette) == "table" then
	config.color_scheme = nil
	config.colors = palette
else
	config.colors = nil
	config.color_scheme = "Tokyo Night"
end
config.hide_tab_bar_if_only_one_tab = true
config.window_padding = {
	left = 0,
	right = 0,
	top = 0,
	bottom = 0,
}
-- Leichte Transparenz; Hyprland-Blur greift dahinter (siehe decoration.blur in hyprland.conf).
config.window_background_opacity = 0.9
-- Hyperlink Rules für klickbare Dateipfade (öffnet in Neovim)
config.hyperlink_rules = wezterm.default_hyperlink_rules()

-- Dateipfad mit Zeile:Spalte (z.B. src/main.rs:42:10)
table.insert(config.hyperlink_rules, {
	regex = [[([\w\d_\-./]+\.[\w]+):(\d+):(\d+)]],
	format = "editor://$1:$2:$3",
})

-- Dateipfad mit Zeile (z.B. src/main.rs:42)
table.insert(config.hyperlink_rules, {
	regex = [[([\w\d_\-./]+\.[\w]+):(\d+)]],
	format = "editor://$1:$2",
})

-- Kopiere Maus-Selektion automatisch ins Clipboard
config.mouse_bindings = {
	{
		event = { Up = { streak = 1, button = "Left" } },
		mods = "NONE",
		action = wezterm.action.CompleteSelectionOrOpenLinkAtMouseCursor("ClipboardAndPrimarySelection"),
	},
	{
		event = { Down = { streak = 1, button = "Left" } },
		mods = "NONE",
		action = wezterm.action.SelectTextAtMouseCursor("Cell"),
	},
}

config.keys = {
	{
		key = "k",
		mods = "CTRL|SHIFT",
		action = wezterm.action.ClearScrollback("ScrollbackOnly"),
	},
	{
		key = "r",
		mods = "CTRL|SHIFT",
		action = wezterm.action.ReloadConfiguration,
	},
	{
		key = "w",
		mods = "CTRL|SHIFT",
		action = wezterm.action.DisableDefaultAssignment,
	},
	{
		key = "v",
		mods = "CTRL",
		action = wezterm.action.PasteFrom("Clipboard"),
	},
	-- Physische US-Positionen (= DE ß und ´) deaktivieren
	{ key = "phys:Minus", mods = "CTRL", action = wezterm.action.DisableDefaultAssignment },
	{ key = "phys:Equal", mods = "CTRL", action = wezterm.action.DisableDefaultAssignment },
	{ key = "phys:Equal", mods = "CTRL|SHIFT", action = wezterm.action.DisableDefaultAssignment },
	-- Zoom über die deutschen Zeichen binden
	{ key = "+", mods = "CTRL", action = wezterm.action.IncreaseFontSize },
	{ key = "-", mods = "CTRL", action = wezterm.action.DecreaseFontSize },
	{ key = "0", mods = "CTRL", action = wezterm.action.ResetFontSize },
}

return config
