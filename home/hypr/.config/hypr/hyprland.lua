local mainMod = "SUPER"

hl.config({
    general = {
        gaps_in = 1,
        gaps_out = 0,
        border_size = 0,
        layout = "dwindle",

        resize_on_border = true,
        extend_border_grab_area = 15,
        hover_icon_on_border = true,
    },

    decoration = {
        rounding = 0,
        active_opacity = 1.0,
        inactive_opacity = 1.0,

        blur = {
            enabled = true,
            size = 12,
            passes = 3,
            new_optimizations = true,
            popups = true,
    }
    },

    input = {
        kb_layout = "latam",
        touchpad = {
            natural_scroll = true,
        },
    },

    misc = {
        disable_hyprland_logo = true,
    },
    dwindle = {
        preserve_split = true,
    },
})

-- ============================================================
-- APLICACIONES
-- ============================================================

-- Terminal
hl.bind("SUPER + T", hl.dsp.exec_cmd("ghostty"))

-- Launcher
hl.bind(
    "SUPER + SPACE",
    hl.dsp.exec_cmd("rofi -show drun -wayland-layer overlay")
)
hl.bind(
    "SUPER + SHIFT + SPACE",
    hl.dsp.exec_cmd("rofi -show filebrowser -wayland-layer overlay")
)

-- arranque
hl.on("hyprland.start", function()
    hl.exec_cmd("~/.local/bin/random-wallpaper")
    hl.exec_cmd("~/.local/bin/waybar-session start")
    hl.exec_cmd("dunst")
    hl.exec_cmd("env LANG=C.UTF-8 LC_ALL=C.UTF-8 /usr/libexec/polkit-mate-authentication-agent-1")
    hl.exec_cmd("~/.local/bin/network-keyring-agent")
    hl.exec_cmd("quickshell -c default")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("hyprsunset")
end)

-- ============================================================
-- VENTANAS
-- ============================================================

-- Cerrar ventana
hl.bind("ALT + F4", hl.dsp.window.close())

-- ============================================================
-- WORKSPACES
-- ============================================================

-- Cambiar al workspace anterior/siguiente
hl.bind(
    "SUPER + ALT + LEFT",
    hl.dsp.focus({ workspace = "r-1" })
)

hl.bind(
    "SUPER + ALT + RIGHT",
    hl.dsp.focus({ workspace = "r+1" })
)

-- Mover ventana actual al workspace anterior/siguiente
hl.bind(
    "SUPER + ALT + SHIFT + LEFT",
    hl.dsp.window.move({
        workspace = "r-1",
        follow = true,
    })
)

hl.bind(
    "SUPER + ALT + SHIFT + RIGHT",
    hl.dsp.window.move({
        workspace = "r+1",
        follow = true,
    })
)
-- ============================================================
-- NAVEGACIÓN ENTRE VENTANAS
-- ============================================================

hl.bind(
    "SUPER + LEFT",
    hl.dsp.focus({ direction = "l" })
)

hl.bind(
    "SUPER + RIGHT",
    hl.dsp.focus({ direction = "r" })
)

hl.bind(
    "SUPER + UP",
    hl.dsp.focus({ direction = "u" })
)

hl.bind(
    "SUPER + DOWN",
    hl.dsp.focus({ direction = "d" })
)
-- ============================================================
-- ANIMACIONES
-- ============================================================
hl.curve(
    "smooth",
    {
        type = "bezier",
        points = {
            { 0.22, 1.0 },
            { 0.36, 1.0 }
        }
    }
)

hl.animation({
    leaf = "windows",
    enabled = true,
    speed = 4,
    bezier = "smooth",
    style = "popin 90%"
})

hl.animation({
    leaf = "windowsIn",
    enabled = true,
    speed = 4,
    bezier = "smooth",
    style = "popin 90%"
})

hl.animation({
    leaf = "windowsOut",
    enabled = true,
    speed = 3,
    bezier = "smooth"
})

hl.animation({
    leaf = "windowsMove",
    enabled = true,
    speed = 3,
    bezier = "smooth"
})

hl.animation({
    leaf = "fade",
    enabled = true,
    speed = 3,
    bezier = "smooth"
})

hl.animation({
    leaf = "workspaces",
    enabled = true,
    speed = 2,
    bezier = "smooth",
    style = "slidefade 10%"
})
-- ============================================================
-- ESCRITORIO
-- ============================================================

-- Nautilus
hl.bind("SUPER + E", hl.dsp.exec_cmd("nautilus"))


hl.bind(
    "XF86AudioRaiseVolume",
    hl.dsp.exec_cmd("wpctl set-volume --limit 1.5 @DEFAULT_AUDIO_SINK@ 5%+"),
    { repeating = true }
)

hl.bind(
    "XF86AudioLowerVolume",
    hl.dsp.exec_cmd("wpctl set-volume --limit 1.5 @DEFAULT_AUDIO_SINK@ 5%-"),
    { repeating = true }
)

hl.bind(
    "XF86AudioMute",
    hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
    { locked = true }
)

-- Brillo
hl.bind(
    "XF86MonBrightnessUp",
    hl.dsp.exec_cmd("~/.local/bin/brightness-osd up"),
    { repeating = true }
)

hl.bind(
    "XF86MonBrightnessDown",
    hl.dsp.exec_cmd("~/.local/bin/brightness-osd down"),
    { repeating = true }
)

hl.layer_rule({
    match = {
        namespace = "waybar",
    },
    blur = true,
    blur_popups = true,
    ignore_alpha = 0.2,
})
hl.layer_rule({
    match = {
        namespace = "notifications",
    },
    blur = true,
    blur_popups = true,
    ignore_alpha = 0.2,
})
hl.layer_rule({
    match = {
        namespace = "quickshell",
    },
    blur = true,
    blur_popups = true,
    ignore_alpha = 0.2,
})
-- ============================================================
-- ROFI
-- ============================================================

hl.curve(
    "rofiSmooth",
    {
        type = "bezier",
        points = {
            { 0.25, 0.95 },
            { 0.35, 1.0 }
        }
    }
)

hl.animation({
    leaf = "layers",
    enabled = true,
    speed = 1,
    bezier = "rofiSmooth",
    style = "popin 99%"
})

hl.layer_rule({
    match = {
        namespace = "rofi",
    },
    blur = true,
    blur_popups = true,
    ignore_alpha = 0.2,
    animation = "popin 99% rofiSmooth",
})

hl.bind(
    "PRINT",
    hl.dsp.exec_cmd("~/.local/bin/take-screenshot")
)

hl.bind(
    "SUPER + V",
    hl.dsp.exec_cmd("~/.local/bin/rofi-clipboard")
)

hl.bind(
    "SUPER + L",
    hl.dsp.exec_cmd("hyprlock")
)

hl.bind(
    "SUPER + N",
    hl.dsp.exec_cmd("~/.local/bin/toggle-night-light")
)

hl.bind(
    "SUPER + W",
    hl.dsp.exec_cmd("~/.local/bin/random-wallpaper")
)

hl.bind(
    "SUPER + P",
    hl.dsp.exec_cmd("~/.local/bin/toggle-power-profile")
)

hl.bind("SUPER + G", function()
    local window = hl.get_active_window()

    if window == nil then
        return
    end

    if window.floating then
        hl.dispatch(hl.dsp.window.float({ action = "unset" }))
    else
        hl.dispatch(hl.dsp.window.float({ action = "set" }))
        hl.dispatch(hl.dsp.window.resize({
            x = 1000,
            y = 650,
        }))
        hl.dispatch(hl.dsp.window.center())
    end
end)

hl.window_rule({
    match = {
        content = "game",
        fullscreen = true,
    },
    confine_pointer = true,
})
hl.window_rule({
    match = {
        class = "^cs2$",
    },
    confine_pointer = true,
})
