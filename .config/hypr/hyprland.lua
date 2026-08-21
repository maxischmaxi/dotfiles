-- Hyprland-Config (Lua) — migriert aus hyprland.conf (Hyprland 0.55+).
-- Seit 0.55 ist hyprlang deprecated; Hyprland bevorzugt diese Datei gegenüber
-- hyprland.conf. Die alte hyprland.conf wurde am 2026-07-19 entfernt, es gibt
-- also keinen hyprlang-Fallback mehr — bei einem Lua-Fehler startet Hyprland mit
-- Defaults. Alte Fassung liegt in der Git-History von ~/.config.
-- Voller Options-/API-Überblick: https://wiki.hypr.land/Configuring/Start/

------------------------------------------------------------------
-- Farben (matugen)
-- colors.lua wird bei jedem Wallpaper-Wechsel neu erzeugt. Das package.loaded-
-- Reset erzwingt frisches Einlesen, damit `hyprctl reload` neue Farben übernimmt
-- (statt eine gecachte require-Kopie zu behalten). Fällt robust auf {} zurück,
-- falls die Datei (noch) fehlt.
------------------------------------------------------------------
if package and package.loaded then
	package.loaded["colors"] = nil
end
local ok_colors, colors = pcall(require, "colors")
if not ok_colors or type(colors) ~= "table" then
	colors = {}
end
local function theme(name, fallback)
	return colors[name] or fallback
end

------------------------------------------------------------------
-- Programme / Variablen
------------------------------------------------------------------
local terminal = "ghostty"
local fileManager = "thunar"
local menu = "rofi -show drun"
local mainMod = "SUPER"

------------------------------------------------------------------
-- Layout-Modus
-- "scrolling" = niri-style tape, "floating" = every window floats.
-- Only knob to flip: change the value, then `hyprctl reload`.
-- It switches general.layout, the catch-all float rule, shadows and
-- the layout-specific keybinds further down in one go.
------------------------------------------------------------------
local layoutMode = "floating"
local floating = layoutMode == "floating"

------------------------------------------------------------------
-- Monitore (Namen/Modes via `hyprctl monitors`)
-- desc: statt Port-Name — die DP-/HDMI-Namen wechseln je nach Boot/Treiber.
-- desc bindet an die EDID (Modell + Serial) und bleibt stabil.
------------------------------------------------------------------
-- ASUS XG32UCDS 32" 4K@165 – einziger Monitor
hl.monitor({
	output = "desc:ASUSTek COMPUTER INC XG32UCDS T8LMQS046296",
	mode = "3840x2160@165",
	position = "0x0",
	scale = 1,
})
-- Fallback für jeden weiteren/unbekannten Monitor
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

------------------------------------------------------------------
-- Umgebungsvariablen
------------------------------------------------------------------
-- $TERMINAL gilt fuer alles, was Hyprland startet (rofi-Launches inklusive) —
-- anders als ein Export in der zshrc, den nur Shell-Kinder sehen.
hl.env("TERMINAL", "ghostty")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_STYLE_OVERRIDE", "kvantum")
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("HYPRCURSOR_SIZE", "24")

------------------------------------------------------------------
-- Workspaces an Monitore binden
------------------------------------------------------------------
-- Single-Display: Workspace 1 ist Default, weitere Workspaces brauchen keine
-- Monitor-Bindung mehr.
hl.workspace_rule({ workspace = "1", monitor = "desc:ASUSTek COMPUTER INC XG32UCDS T8LMQS046296", default = true })

------------------------------------------------------------------
-- exec (bei jedem Config-Load) — GTK-Theme-Settings
------------------------------------------------------------------
hl.exec_cmd('gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"')
hl.exec_cmd('gsettings set org.gnome.desktop.interface gtk-theme "Tokyonight-Dark"')
hl.exec_cmd('gsettings set org.gnome.desktop.interface icon-theme "Tokyonight-Moon"')
-- "Terminal hier oeffnen" in GTK-Apps (Thunar & Co). Stand vorher auf
-- xdg-terminal-exec, das gar nicht installiert ist — war also kaputt.
hl.exec_cmd('gsettings set org.gnome.desktop.default-applications.terminal exec "ghostty"')
hl.exec_cmd('gsettings set org.gnome.desktop.default-applications.terminal exec-arg "-e"')

------------------------------------------------------------------
-- Autostart (einmalig beim Hyprland-Start = vormals exec-once)
------------------------------------------------------------------
hl.on("hyprland.start", function()
	hl.exec_cmd("/home/max/.config/hypr/scripts/pip-autofloat.py")
	hl.exec_cmd(
		"dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE"
	)
	-- Zieht graphical-session.target hoch -> xdg-desktop-portal(-hyprland) -> Screen-Sharing
	hl.exec_cmd("systemctl --user start hyprland-session.target")
	hl.exec_cmd("swaync")
	hl.exec_cmd("wl-paste --watch cliphist store")
	hl.exec_cmd("systemctl --user start hypridle.service")
end)

-- Raise on focus: Hyprland keeps the floating stack as it is when focus moves,
-- so a window can stay buried under the one you just left. There is no config
-- option for it, so do it on every focus change. No-op for tiled windows.
hl.on("window.active", function()
	hl.dispatch(hl.dsp.window.bring_to_top())
end)

------------------------------------------------------------------
-- Look & Feel + Input
------------------------------------------------------------------
hl.config({
	general = {
		-- floating mode still needs a tiling layout underneath for anything the
		-- catch-all rule misses; dwindle is the harmless fallback.
		layout = floating and "dwindle" or "scrolling",
		gaps_in = 0,
		gaps_out = 0,
		-- No borders: focus is marked by dimming the inactive windows instead
		-- (decoration.dim_inactive below). The colors stay in case border_size
		-- ever goes above 0 again — hardcoded so the matugen refresh cannot
		-- brighten them.
		border_size = 0,
		col = {
			active_border = "rgb(5a6b8c)",
			inactive_border = "rgb(000000)",
		},
		resize_on_border = false,
		allow_tearing = false,
	},

	dwindle = {
		preserve_split = true,
	},

	-- niri-style: windows live on an infinite horizontal tape
	scrolling = {
		direction = "right",
		column_width = 0.5,
		fullscreen_on_one_column = true,
		focus_fit_method = 1, -- 0 = center, 1 = fit
		follow_focus = true,
		explicit_column_widths = "0.333, 0.5, 0.667, 1.0",
	},

	master = {
		mfact = 0.6,
		new_status = "master",
	},

	group = {
		-- OLED-Schonung: aktive (wandernde) Gruppen-Border gedämpft, inaktive schwarz.
		col = {
			border_active = "rgb(5a6b8c)",
			border_inactive = "rgb(000000)",
			border_locked_active = "rgb(5a6b8c)",
			border_locked_inactive = "rgb(000000)",
		},
		groupbar = {
			enabled = true,
			font_size = 12,
			height = 22,
			text_color = theme("on_surface", "rgb(dfe2ef)"),
			text_padding = 8,
			render_titles = true,
			gradients = true,
			gradient_rounding = 6,
			round_only_edges = true,
			indicator_height = 3,
			indicator_gap = 2,
			gaps_in = 4,
			gaps_out = 2,
			col = {
				active = {
					colors = {
						theme("primary_container", "rgb(004492)"),
						theme("surface_container_high", "rgb(262a33)"),
					},
					angle = 45,
				},
				inactive = theme("surface_container", "rgb(1b2029)"),
				locked_active = {
					colors = {
						theme("primary_container", "rgb(004492)"),
						theme("surface_container_high", "rgb(262a33)"),
					},
					angle = 45,
				},
				locked_inactive = theme("surface_container", "rgb(1b2029)"),
			},
		},
	},

	decoration = {
		rounding = 10,
		rounding_power = 2,
		active_opacity = 1.0,
		inactive_opacity = 1.0,
		-- Focus marker instead of a border: everything inactive gets darkened.
		-- dim_strength is 0..1, upstream default is 0.5.
		dim_inactive = true,
		dim_strength = 0.4,
		shadow = {
			-- Off in every layout mode: render_power 3 is the priciest step and
			-- telling windows apart is the dimming's job now.
			-- To bring it back: enabled = true.
			enabled = false,
			range = 20,
			render_power = 3,
			color = "rgba(1a1a1aee)",
		},
		blur = {
			-- Aus: die einzige transparente Fläche ist rofi (alpha 0.93), also
			-- >90% deckend. Dahinter liegt mit
			-- xray = true ohnehin nur der einfarbig schwarze background_color —
			-- verwischtes Schwarz ist Schwarz. Kostet also Fläche ohne Wirkung.
			-- Zum Reaktivieren: enabled = true (Werte unten sind noch gesetzt).
			enabled = false,
			size = 4,
			passes = 2,
			new_optimizations = true,
			xray = true,
			vibrancy = 0.1696,
		},
	},

	animations = {
		enabled = true,
	},

	misc = {
		force_default_wallpaper = 0,
		disable_hyprland_logo = true,
		-- Schwarzer Desktop-Hintergrund direkt vom Compositor (kein Wallpaper-Tool nötig).
		-- Braucht disable_hyprland_logo = true (oben gesetzt).
		background_color = "rgb(000000)",
		-- VRR nur im Fullscreen. Nutzt Adaptive Sync des XG32UCDS bei Games/Video,
		-- vermeidet aber das Helligkeitsflackern, das manche Panels im Desktop-
		-- Betrieb bei stark schwankender Framerate zeigen.
		vrr = 2,
	},

	cursor = {
		-- Auf NVIDIA deaktiviert aquamarine HW-Cursor per Default (Wert "auto" = 2),
		-- wegen alter Treiber-Bugs. Mit 610.x laufen sie wieder. Spart ein
		-- Fullscreen-Repaint pro Mausbewegung und entsperrt Direct Scanout.
		-- Bei Cursor-Flackern oder unsichtbarem Cursor: wieder auf true setzen.
		no_hardware_cursors = false,
	},

	render = {
		-- Reicht den Buffer einer Fullscreen-App direkt an den Scanout durch,
		-- statt ihn durch die Komposition zu schicken. Braucht HW-Cursor (oben).
		direct_scanout = 1,
	},

	binds = {
		-- Default 300: innerhalb des Fensters lösen Scroll-Events keinen Bind aus
		-- und landen stattdessen in der App (Chrome scrollt mit). 0 = jeder Tick
		-- triggert den Bind und wird dadurch geschluckt.
		scroll_event_delay = 0,
	},

	input = {
		kb_layout = "de,ua",
		kb_variant = "nodeadkeys,",
		kb_model = "",
		kb_options = "compose:ralt_toggle,terminate:ctrl_alt_bksp,ctrl:nocaps,grp_led:scroll",
		kb_rules = "",
		numlock_by_default = true,
		repeat_rate = 50,
		repeat_delay = 300,
		follow_mouse = 0,
		sensitivity = -0.85,
		touchpad = {
			natural_scroll = false,
		},
	},
})

------------------------------------------------------------------
-- Animations-Kurven & -Zuordnungen
------------------------------------------------------------------
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1.0 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

-- speed = Dauer in ds (1 = 100ms), also: kleiner = schneller. Durchgehend etwa
-- halbierte Upstream-Defaults. windowsMove ist explizit gesetzt, weil daran das
-- Sliden im Scrolling-Layout hängt.
hl.animation({ leaf = "global", enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 2.5, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 2, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 1.8, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 0.9, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 0.9, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 0.75, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 1.5, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 2, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 2, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 0.9, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 0.9, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 0.75, bezier = "almostLinear" })
-- Workspaces sit side by side (style = "slide", horizontal), but switching
-- jumps without animation. The style stays set so flipping enabled = true
-- slides horizontally instead of vertically.
hl.animation({ leaf = "workspaces", enabled = false, speed = 1, bezier = "almostLinear", style = "slide" })
hl.animation({ leaf = "workspacesIn", enabled = false, speed = 1, bezier = "almostLinear", style = "slide" })
hl.animation({ leaf = "workspacesOut", enabled = false, speed = 1, bezier = "almostLinear", style = "slide" })

------------------------------------------------------------------
-- Keybindings
------------------------------------------------------------------
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
-- ENTER = real fullscreen, for video and games (direct scanout). F is bound
-- per layout mode further down.
hl.bind(mainMod .. " + Return", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exit())
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float())
hl.bind(mainMod .. " + O", hl.dsp.layout("togglesplit"))
hl.bind("ALT + SPACE", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + ESCAPE", hl.dsp.exec_cmd("nwg-bar -i 64"))
hl.bind(mainMod .. " + G", hl.dsp.group.toggle())
hl.bind(mainMod .. " + TAB", hl.dsp.group.next())
hl.bind(mainMod .. " + SHIFT + TAB", hl.dsp.group.prev())

-- Info-Shortcuts (Uhr / Notifications)
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("~/.config/hypr/scripts/show-time.sh"))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("swaync-client -t"))

-- ALT+TAB, replacing hyprshell. Windows are ordered most-recently-used, so the
-- window you are not looking at is preselected: tap ALT+TAB and let go to
-- toggle between two windows. Holding ALT and tapping TAB walks further down,
-- SHIFT reverses. The focus only moves once ALT is released.
--
-- Two implementations, and the binds pick per keystroke:
--   1. the hypr-altswitch plugin, which draws real window thumbnails
--   2. this Lua one, which draws the list as a Hyprland notification
-- If the plugin is missing (not built, or rejected after a Hyprland update
-- changed the ABI) or has disabled itself, the Lua one takes over silently —
-- ALT+TAB always does something.
local switcher = { list = nil, index = 1, notif = nil }

local function altHeld()
	return hl.is_key_down("Alt_L") or hl.is_key_down("Alt_R")
end

-- Byte-safe clip: never cut a UTF-8 sequence in half.
local function clip(str, max)
	if #str <= max then
		return str
	end
	local cut = max
	local nextByte = str:byte(cut + 1)
	while cut > 1 and nextByte and nextByte >= 0x80 and nextByte < 0xC0 do
		cut = cut - 1
		nextByte = str:byte(cut + 1)
	end
	return str:sub(1, cut) .. "…"
end

local function switcherText()
	local lines = {}
	for i, w in ipairs(switcher.list) do
		-- com.mitchellh.ghostty -> ghostty, google-chrome stays as it is
		local name = (w.class or ""):match("[^.]+$") or "?"
		local title = clip(w.title or "", 38)
		lines[#lines + 1] = (i == switcher.index and "▸  " or "     ") .. name .. (title ~= "" and ("   " .. title) or "")
	end
	return table.concat(lines, "\n")
end

local function drawSwitcher()
	local text = switcherText()
	if switcher.notif and switcher.notif:is_alive() then
		switcher.notif:set_text(text)
		switcher.notif:set_timeout(5000)
	else
		switcher.notif = hl.notification.create({
			text = text,
			timeout = 5000,
			-- swaync's text-muted; Hyprland paints it as the left accent bar.
			-- No markup available here, the renderer prints tags verbatim.
			color = "rgb(9a9aa2)",
			font_size = 11,
		})
	end
end

-- Apply the selection and tear the overlay down. Idempotent: the release bind
-- and the watchdog below may both land on it.
local function commitSwitcher()
	local win = switcher.list and switcher.list[switcher.index]
	if switcher.notif then
		pcall(function()
			switcher.notif:dismiss()
		end)
		switcher.notif = nil
	end
	switcher.list, switcher.index = nil, 1
	if win then
		-- a window from the frozen list can be gone by now
		pcall(function()
			hl.dispatch(hl.dsp.focus({ window = win }))
		end)
	end
end

local function altTab(step)
	return function()
		-- Start a fresh cycle unless one is running with ALT still down.
		if not switcher.list or not altHeld() then
			local wins = {}
			for _, w in ipairs(hl.get_windows()) do
				if w.mapped and not w.hidden then
					wins[#wins + 1] = w
				end
			end
			-- focus_history_id: 0 is the focused window, 1 the one before it, ...
			table.sort(wins, function(a, b)
				return a.focus_history_id < b.focus_history_id
			end)
			if #wins < 2 then
				return
			end
			switcher.list, switcher.index = wins, 1
		end
		switcher.index = (switcher.index + step - 1) % #switcher.list + 1
		drawSwitcher()
	end
end

-- Path to the built plugin, or nil to stay on the Lua switcher.
-- Build it with: cd /stuff/programming/hypr-altswitch && make
local switcherPluginPath = "/home/max/.local/share/hyprland/plugins/hypr-altswitch.so"

-- Returns the plugin namespace only if it is loaded AND still reports itself
-- healthy. hl.plugin.load() does not report failures back, so asking for the
-- namespace afterwards is the only reliable check.
local function switcherPlugin()
	local ns = hl.plugin and hl.plugin.altswitch
	if type(ns) ~= "table" or type(ns.healthy) ~= "function" then
		return nil
	end
	local ok, healthy = pcall(ns.healthy)
	if ok and healthy then
		return ns
	end
	return nil
end

if switcherPluginPath then
	pcall(function()
		hl.plugin.load(switcherPluginPath)
	end)
	if not switcherPlugin() then
		hl.notification.create({
			text = "alt-tab: plugin not loaded, using the built-in list.\nrebuild it after a Hyprland update.",
			timeout = 6000,
			color = "rgb(9a9aa2)",
			font_size = 11,
		})
	end
end

-- Watchdog, shared by both implementations. The ALT release bind is not
-- guaranteed to fire, and an overlay nobody closes just sits there: the Lua list
-- hid that behind its own 5s notification timeout, the plugin overlay has none.
--
-- It calibrates itself. At the moment ALT+TAB fires, ALT is held by definition —
-- so if is_key_down disagrees right there, key state is unusable in this session
-- and the watchdog closes on inactivity instead of on release.
local watchdog = { timer = nil, idle = 0, keyStateUsable = false }


-- Declared up front: watchdog and commit call each other.
local switchCommit, watchdogStart, watchdogStop

local function switcherIsOpen()
	if switcher.list then
		return true
	end
	local ns = switcherPlugin()
	if ns then
		local ok, active = pcall(ns.active)
		return ok and active == true
	end
	return false
end

watchdogStop = function()
	watchdog.idle = 0
	if watchdog.timer then
		watchdog.timer:set_enabled(false)
	end
end

watchdogStart = function()
	watchdog.idle           = 0
	watchdog.keyStateUsable = altHeld()

	if not watchdog.timer then
		watchdog.timer = hl.timer(function()
			if not switcherIsOpen() then
				watchdogStop()
				return
			end
			if watchdog.keyStateUsable then
				if not altHeld() then
					switchCommit()
				end
				return
			end
			-- No usable key state: close ~1.5s after the last keypress.
			watchdog.idle = watchdog.idle + 1
			if watchdog.idle > 25 then
				switchCommit()
			end
		end, { timeout = 60, type = "repeat" })
	end
	watchdog.timer:set_enabled(true)
end

-- Every step tries the plugin first and falls through to Lua on any failure,
-- so a plugin that dies mid-cycle costs one keystroke, not the feature.
local function switchStep(step)
	local luaStep = altTab(step)
	return function()
		local ns = switcherPlugin()
		if not (ns and pcall(step > 0 and ns.next or ns.prev)) then
			luaStep()
		end
		watchdogStart()
	end
end

switchCommit = function()
	local ns = switcherPlugin()
	if ns then
		pcall(ns.commit)
	end
	-- Also close the Lua one: a no-op when idle, and it is what cleans up if the
	-- plugin fell over while its overlay was on screen.
	commitSwitcher()
	watchdogStop()
end

hl.bind("ALT + Tab", switchStep(1))
hl.bind("ALT + SHIFT + Tab", switchStep(-1))
-- non_consuming: ALT on its own must still reach the app (Chrome's menu bar and
-- friends react to a bare ALT press/release).
-- No modifier on these: by the time ALT comes up, the ALT modifier is already
-- gone, so "ALT + Alt_L" never matches — measured, it fired exactly zero times.
-- Without a modifier they fire on every ALT release; switchCommit is a no-op
-- when no switcher is open, and non_consuming keeps a bare ALT reaching the app.
hl.bind("Alt_L", function() switchCommit() end, { release = true, non_consuming = true })
hl.bind("Alt_R", function() switchCommit() end, { release = true, non_consuming = true })

-- Workspace vor/zurück inkl. leerer (vormals `exec, hyprctl dispatch workspace r±1`)
hl.bind(mainMod .. " + N", hl.dsp.focus({ workspace = "r+1" }))
hl.bind(mainMod .. " + P", hl.dsp.focus({ workspace = "r-1" }))
-- move the window to the next/previous workspace (used to sit on SHIFT+j/k)
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.window.move({ workspace = "r+1" }))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.window.move({ workspace = "r-1" }))

-- Screenshots / Screencast
hl.bind("CTRL + ALT + 4", hl.dsp.exec_cmd('grim -g "$(slurp)" - | swappy -f -'))
hl.bind("Print", hl.dsp.exec_cmd("grim - | swappy -f -"))
hl.bind("CTRL + ALT + 5", hl.dsp.exec_cmd("~/.config/hypr/scripts/record-region.sh"))

-- Aktives Fenster größer/kleiner
hl.bind(mainMod .. " + left", hl.dsp.window.resize({ x = -40, y = 0, relative = true }))
hl.bind(mainMod .. " + right", hl.dsp.window.resize({ x = 40, y = 0, relative = true }))
hl.bind(mainMod .. " + up", hl.dsp.window.resize({ x = 0, y = -40, relative = true }))
hl.bind(mainMod .. " + down", hl.dsp.window.resize({ x = 0, y = 40, relative = true }))

-- Horizontal focus, step = 1 (right) or -1 (left). Hyprland's own direction
-- focus wraps around at the edge, which is exactly what we don't want: at the
-- outer edge this jumps to the neighbouring workspace instead — and only if
-- that one actually holds windows, otherwise nothing happens at all.
local function focusHorizontal(step)
	return function()
		local ws = hl.get_active_workspace()
		if not ws then
			return
		end
		-- nearest window in that direction, measured center to center;
		-- vertical distance only breaks ties (0.5 weight).
		local active = hl.get_active_window()
		if active then
			local acx = active.at.x + active.size.x / 2
			local acy = active.at.y + active.size.y / 2
			local best, bestScore
			for _, w in ipairs(hl.get_workspace_windows(ws)) do
				if w.address ~= active.address then
					local dx = (w.at.x + w.size.x / 2 - acx) * step
					if dx > 1 then
						local score = dx + math.abs(w.at.y + w.size.y / 2 - acy) * 0.5
						if not bestScore or score < bestScore then
							best, bestScore = w, score
						end
					end
				end
			end
			if best then
				hl.dispatch(hl.dsp.focus({ window = best }))
				return
			end
		end
		-- edge reached: only cross over if the neighbour has windows
		if ws.special or ws.id < 1 then
			return
		end
		local target = hl.get_workspace(ws.id + step)
		if not target or target.windows < 1 then
			return
		end
		-- land on the window closest to the edge we came from
		local edge, edgeScore
		for _, w in ipairs(hl.get_workspace_windows(target)) do
			local score = (w.at.x + w.size.x / 2) * step
			if not edgeScore or score < edgeScore then
				edge, edgeScore = w, score
			end
		end
		hl.dispatch(hl.dsp.focus({ workspace = target }))
		if edge then
			hl.dispatch(hl.dsp.focus({ window = edge }))
		end
	end
end

-- In scrolling mode h/l scroll the tape (focus drags the view along and wraps
-- at the end instead of leaving for the neighbouring monitor); in floating they
-- walk the windows and then carry on across workspaces.
if floating then
	hl.bind(mainMod .. " + h", focusHorizontal(-1))
	hl.bind(mainMod .. " + l", focusHorizontal(1))
else
	hl.bind(mainMod .. " + h", hl.dsp.layout("focus l"))
	hl.bind(mainMod .. " + l", hl.dsp.layout("focus r"))
end
-- j/k only move focus down/up. Workspaces live on SUPER+1..0 and N/P now.
hl.bind(mainMod .. " + j", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + k", hl.dsp.focus({ direction = "up" }))

-- Usable area of a window's monitor: full size minus reserved edges, scale
-- corrected. Both snapping and scaling below work against it.
local function usableArea(win)
	local m = (win and win.monitor) or hl.get_monitor_at_cursor()
	if not m then
		return nil
	end
	local r = m.reserved or {}
	local scale = m.scale or 1
	return {
		x = m.x + (r.left or 0),
		y = m.y + (r.top or 0),
		w = m.width / scale - (r.left or 0) - (r.right or 0),
		h = m.height / scale - (r.top or 0) - (r.bottom or 0),
	}
end

-- Snapping: Hyprland has no notion of screen halves, so do the math here.
-- fx/fy = position, fw/fh = size, each as a fraction of the usable area.
local function snap(fx, fy, fw, fh)
	return function()
		local win = hl.get_active_window()
		local a = win and usableArea(win)
		if not a then
			return
		end
		if not win.floating then
			hl.dispatch(hl.dsp.window.float({ action = "enable" }))
		end
		hl.dispatch(hl.dsp.window.resize({ x = math.floor(a.w * fw), y = math.floor(a.h * fh) }))
		hl.dispatch(hl.dsp.window.move({ x = math.floor(a.x + a.w * fx), y = math.floor(a.y + a.h * fy) }))
	end
end

-- Grow/shrink around the window's center. Clamped to the usable area and to a
-- floor of 320x200 so a window can never be scaled into nothing.
local function scaleWindow(factor)
	return function()
		local win = hl.get_active_window()
		local a = win and usableArea(win)
		if not a then
			return
		end
		local nw = math.floor(math.max(320, math.min(a.w, win.size.x * factor)))
		local nh = math.floor(math.max(200, math.min(a.h, win.size.y * factor)))
		local nx = math.floor(win.at.x + (win.size.x - nw) / 2)
		local ny = math.floor(win.at.y + (win.size.y - nh) / 2)
		-- pull back inside the work area if the center moved it past an edge
		nx = math.max(a.x, math.min(a.x + a.w - nw, nx))
		ny = math.max(a.y, math.min(a.y + a.h - nh, ny))
		if not win.floating then
			hl.dispatch(hl.dsp.window.float({ action = "enable" }))
		end
		hl.dispatch(hl.dsp.window.resize({ x = nw, y = nh }))
		hl.dispatch(hl.dsp.window.move({ x = nx, y = ny }))
	end
end

if floating then
	-- +/- scale by 10% in both directions; shrinking uses 1/1.1 so that a plus
	-- and a minus cancel each other out exactly.
	hl.bind(mainMod .. " + plus", scaleWindow(1.1))
	hl.bind(mainMod .. " + minus", scaleWindow(1 / 1.1))
	hl.bind(mainMod .. " + KP_Add", scaleWindow(1.1))
	hl.bind(mainMod .. " + KP_Subtract", scaleWindow(1 / 1.1))

	-- SUPER+F fills the usable area by resizing instead of entering Hyprland's
	-- maximize mode: a maximized or fullscreen window leaves the floating stack,
	-- and raise-on-focus can no longer lift it above the others. Pressing it
	-- again returns to the centered default size.
	hl.bind(mainMod .. " + F", function()
		local win = hl.get_active_window()
		local a = win and usableArea(win)
		if not a then
			return
		end
		if win.size.x >= a.w - 4 and win.size.y >= a.h - 4 then
			snap(0.2, 0.15, 0.6, 0.7)()
		else
			snap(0, 0, 1, 1)()
		end
	end)

	-- halves on SHIFT+hjkl
	hl.bind(mainMod .. " + SHIFT + h", snap(0, 0, 0.5, 1))
	hl.bind(mainMod .. " + SHIFT + l", snap(0.5, 0, 0.5, 1))
	hl.bind(mainMod .. " + SHIFT + k", snap(0, 0, 1, 0.5))
	hl.bind(mainMod .. " + SHIFT + j", snap(0, 0.5, 1, 0.5))
	-- quarters on CTRL+1..4, read as a 2x2 grid:
	-- 1 = top left, 2 = top right, 3 = bottom left, 4 = bottom right
	hl.bind(mainMod .. " + CTRL + 1", snap(0, 0, 0.5, 0.5))
	hl.bind(mainMod .. " + CTRL + 2", snap(0.5, 0, 0.5, 0.5))
	hl.bind(mainMod .. " + CTRL + 3", snap(0, 0.5, 0.5, 0.5))
	hl.bind(mainMod .. " + CTRL + 4", snap(0.5, 0.5, 0.5, 0.5))
	-- centered at 60x70% — the default spot for a single window
	hl.bind(mainMod .. " + SHIFT + Return", snap(0.2, 0.15, 0.6, 0.7))

	-- CTRL+hjkl nudges the window pixel-wise (counterpart to the arrow keys
	-- above, which resize).
	hl.bind(mainMod .. " + CTRL + h", hl.dsp.window.move({ x = -60, y = 0, relative = true }))
	hl.bind(mainMod .. " + CTRL + l", hl.dsp.window.move({ x = 60, y = 0, relative = true }))
	hl.bind(mainMod .. " + CTRL + k", hl.dsp.window.move({ x = 0, y = -60, relative = true }))
	hl.bind(mainMod .. " + CTRL + j", hl.dsp.window.move({ x = 0, y = 60, relative = true }))
	hl.bind(mainMod .. " + R", hl.dsp.window.center())
	hl.bind(mainMod .. " + SHIFT + R", hl.dsp.window.pin())
else
	hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
	-- Scrolling-Layout: Spalte verschieben / Ansicht ohne Fokuswechsel / Breiten
	hl.bind(mainMod .. " + SHIFT + h", hl.dsp.layout("swapcol l"))
	hl.bind(mainMod .. " + SHIFT + l", hl.dsp.layout("swapcol r"))
	hl.bind(mainMod .. " + CTRL + h", hl.dsp.layout("move -col"))
	hl.bind(mainMod .. " + CTRL + l", hl.dsp.layout("move +col"))
	hl.bind(mainMod .. " + R", hl.dsp.layout("colresize +conf"))
	hl.bind(mainMod .. " + SHIFT + R", hl.dsp.layout("fit expand"))
	hl.bind(mainMod .. " + BRACKETLEFT", hl.dsp.layout("consume_or_expel prev"))
	hl.bind(mainMod .. " + BRACKETRIGHT", hl.dsp.layout("consume_or_expel next"))
end

-- Workspaces wechseln (SUPER+1..0) / aktives Fenster verschieben (SUPER+SHIFT+1..0)
for i = 1, 10 do
	local key = i % 10 -- 10 -> Taste 0
	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Special workspace (Scratchpad)
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Mausrad: durchs Band scrollen (floating: Fokus nach links/rechts);
-- mit SHIFT stattdessen Workspaces wechseln
if floating then
	hl.bind(mainMod .. " + mouse_down", focusHorizontal(1))
	hl.bind(mainMod .. " + mouse_up", focusHorizontal(-1))
else
	hl.bind(mainMod .. " + mouse_down", hl.dsp.layout("focus r"))
	hl.bind(mainMod .. " + mouse_up", hl.dsp.layout("focus l"))
end
hl.bind(mainMod .. " + SHIFT + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + SHIFT + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Klammern via wtype
hl.bind(mainMod .. " + ALT + h", hl.dsp.exec_cmd("wtype '{'"))
hl.bind(mainMod .. " + ALT + l", hl.dsp.exec_cmd("wtype '}'"))
hl.bind(mainMod .. " + ALT + j", hl.dsp.exec_cmd("wtype '['"))
hl.bind(mainMod .. " + ALT + k", hl.dsp.exec_cmd("wtype ']'"))

-- Maus: Fenster verschieben / skalieren
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Lautstärke / Helligkeit (locked = auch bei Lockscreen, repeating = Wiederholung)
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 1%+"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%-"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

-- Medien-Tasten (playerctld-Proxy: zuletzt aktiver Player, per DBus autogestartet)
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl -p playerctld next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl -p playerctld play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl -p playerctld play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl -p playerctld previous"), { locked = true })

------------------------------------------------------------------
-- Window Rules (Reihenfolge = top-to-bottom, wie in hyprland.conf)
------------------------------------------------------------------
-- Catch-all first: Hyprland has no "floating" layout, this rule *is* the mode.
-- Sits on top so the more specific rules below (rounding, border_size, no_anim)
-- still apply.
if floating then
	hl.window_rule({ match = { class = ".*" }, float = true })
	-- Optional, in case windows open too small on 4K — but this hits dialogs
	-- and PiP as well:
	-- hl.window_rule({ match = { class = ".*" }, size = "60% 60%" })
	-- hl.window_rule({ match = { class = ".*" }, center = true })
end

-- Ghostty opens at its 800x600 toolkit default, which is a postage stamp on 4K.
-- 1920x1166 is half the screen's width and ~160x44 cells at font-size 15
-- (cell ~12x26 px). Pixels, not "50% 54%": the size effect is parsed as a math
-- expression and percent strings silently do not apply.
hl.window_rule({ match = { class = "^(com\\.mitchellh\\.ghostty)$" }, size = "1920 1166" })
hl.window_rule({ match = { class = "^(com\\.mitchellh\\.ghostty)$" }, center = true })

hl.window_rule({ match = { class = "^(jetbrains-studio)$" }, float = true })
hl.window_rule({ match = { class = "^(jetbrains-studio)$" }, no_anim = true })

hl.window_rule({ match = { title = "(MMORPG|MMORPG – Welt-Editor)" }, float = true })

hl.window_rule({ match = { class = "^(Emulator)$", title = "^(Emulator)$" }, float = true })
hl.window_rule({ match = { class = "^(Emulator)$", title = "^(Emulator)$" }, no_anim = true })

hl.window_rule({ match = { class = "^(Godot)$", title = "^Editor.*$" }, float = true })
hl.window_rule({ match = { class = "^(Godot)$", title = "^Please Confirm.*$" }, float = true })

hl.window_rule({ match = { class = "^(steam)$", title = "^(Friends List)$" }, float = true })
hl.window_rule({ match = { class = "^(steam)$", title = "^(Friends List)$" }, no_anim = true })

hl.window_rule({
	match = {
		class = "(steam_app_1808500|install4j-de-espirit-firstspirit-launcher-Launcher|de-espirit-common-bootstrap-Bootstrap)",
	},
	rounding = 0,
})
hl.window_rule({
	match = {
		class = "(steam_app_1808500|install4j-de-espirit-firstspirit-launcher-Launcher|de-espirit-common-bootstrap-Bootstrap)",
	},
	border_size = 0,
})

-- No dimming for the pinned Meet PiP (pip-autofloat.py): that window is never
-- focused by definition and would sit there permanently darkened.
hl.window_rule({ match = { class = "^(google-chrome)$", title = "^Google.*Meet" }, no_dim = true })

hl.window_rule({ match = { title = "^meet.google.com hat ein Fenster freigegeben." }, rounding = 0 })
hl.window_rule({ match = { title = "^meet.google.com hat ein Fenster freigegeben." }, border_size = 0 })

------------------------------------------------------------------
-- Layer Rules
------------------------------------------------------------------
-- blur greift nur, wenn decoration.blur.enabled wieder auf true steht (aktuell aus).
hl.layer_rule({ match = { namespace = "rofi" }, blur = true })
hl.layer_rule({ match = { namespace = "rofi" }, ignore_alpha = 0.3 })
