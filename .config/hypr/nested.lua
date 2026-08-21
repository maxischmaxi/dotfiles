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

-- hypr-altswitch under test. hyprctl inherits this instance's signature from
-- the environment, so it reaches the nested compositor, not the outer one.
hl.bind("ALT + Tab", hl.dsp.exec_cmd("hyprctl dispatch altswitch:next"))
hl.bind("ALT + SHIFT + Tab", hl.dsp.exec_cmd("hyprctl dispatch altswitch:prev"))
hl.bind("ALT + Alt_L", hl.dsp.exec_cmd("hyprctl dispatch altswitch:commit"), { release = true, non_consuming = true })
hl.bind("ALT + Alt_R", hl.dsp.exec_cmd("hyprctl dispatch altswitch:commit"), { release = true, non_consuming = true })
hl.bind("ALT + ESCAPE", hl.dsp.exec_cmd("hyprctl dispatch altswitch:cancel"))
