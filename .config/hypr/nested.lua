-- Throwaway Hyprland for plugin development — runs as a window inside the real
-- session. Deliberately minimal: no autostart, no services, nothing that would
-- talk to the outer session (a second swaync/hypridle/wl-paste would fight with
-- the running ones).
--
-- Start it with ~/.config/hypr/scripts/nested-hyprland.sh
-- Talk to it with `hyprctl -i 1 …` (index 0 is the real session).

hl.monitor({ output = "", mode = "1600x900@60", position = "auto", scale = 1 })

hl.config({
	general = { layout = "dwindle", gaps_in = 4, gaps_out = 8, border_size = 2 },
	decoration = { rounding = 6 },
	animations = { enabled = true },
	misc = {
		disable_hyprland_logo = true,
		force_default_wallpaper = 0,
		background_color = "rgb(101018)",
	},
	input = { kb_layout = "de", kb_variant = "nodeadkeys" },
})

hl.bind("SUPER + Q", hl.dsp.exec_cmd("ghostty"))
hl.bind("SUPER + C", hl.dsp.window.close())
hl.bind("SUPER + M", hl.dsp.exit())

-- hypr-altswitch under test. The plugin exports Lua functions, not dispatchers,
-- so the binds call into hl.plugin.altswitch directly. It is not loaded here:
-- `make load INSTANCE=1` does that, and these binds simply do nothing until it
-- is in. pcall everywhere, so a plugin that dies mid-cycle costs a keystroke
-- rather than breaking the binds.
local function altswitch()
	local ns = hl.plugin and hl.plugin.altswitch
	return type(ns) == "table" and ns or nil
end

local function call(name)
	return function()
		local ns = altswitch()
		if ns and type(ns[name]) == "function" then
			pcall(ns[name])
		end
	end
end

hl.bind("ALT + Tab", call("next"))
hl.bind("ALT + SHIFT + Tab", call("prev"))
hl.bind("ALT + ESCAPE", call("cancel"))
-- No modifier on these: by the time ALT comes up the ALT modifier is already
-- gone, so "ALT + Alt_L" never matches. non_consuming keeps a bare ALT reaching
-- the app, and commit is a no-op when no switcher is open.
hl.bind("Alt_L", call("commit"), { release = true, non_consuming = true })
hl.bind("Alt_R", call("commit"), { release = true, non_consuming = true })
