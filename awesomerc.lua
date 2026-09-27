-- awesome_mode: api-level=4:screen=on
-- If LuaRocks is installed, make sure that packages installed through it are
-- found (e.g. lgi). If LuaRocks is not installed, do nothing.
pcall(require, "luarocks.loader")

-- @DOC_REQUIRE_SECTION@
-- Standard awesome library
local gears = require("gears")
local awful = require("awful")
require("awful.autofocus")
-- Widget and layout library
local wibox = require("wibox")
-- Theme handling library
local beautiful = require("beautiful")
-- Notification library
local naughty = require("naughty")
-- Declarative object management
local ruled = require("ruled")
local menubar = require("menubar")
local hotkeys_popup = require("awful.hotkeys_popup")
-- Enable hotkeys help widget for VIM and other apps
-- when client with a matching name is opened:
require("awful.hotkeys_popup.keys")

-- Load Debian menu entries (from awesome-extra package).
local debian = require("debian.menu")
local has_fdo, freedesktop = pcall(require, "freedesktop")

-- {{{ Error handling
-- Check if awesome encountered an error during startup and fell back to
-- another config (This code will only ever execute for the fallback config)
-- @DOC_ERROR_HANDLING@
naughty.connect_signal("request::display_error", function(message, startup)
    naughty.notification {
        urgency = "critical",
        title   = "Oops, an error happened"..(startup and " during startup!" or "!"),
        message = message
    }
end)
-- }}}

-- {{{ Variable definitions
-- @DOC_LOAD_THEME@
-- Themes define colours, icons, font and wallpapers.
beautiful.init(gears.filesystem.get_themes_dir() .. "default/theme.lua")

-- @DOC_DEFAULT_APPLICATIONS@
-- This is used later as the default terminal and editor to run.
terminal = "xfce4-terminal"
editor = os.getenv("EDITOR") or "editor"
editor_cmd = terminal .. " -e " .. editor

-- Default modkey.
-- Usually, Mod4 is the key with a logo between Control and Alt.
-- If you do not like this or do not have such a key,
-- I suggest you to remap Mod4 to another key using xmodmap or other tools.
-- However, you can use another modifier like Mod1, but it may interact with others.
modkey = "Mod4"

-- Reload safety (2026-09-27): this rc may be re-executed in-process
-- (`echo 'dofile("<rc path>")' | awesome-client`) to hot-apply changes while
-- keeping runtime state such as tag colors. awesome's append-style APIs do
-- NOT dedupe, so a naive re-run stacks one more copy of every keybinding
-- (one keypress then fires N callbacks — found as Win+Enter spawning 3
-- terminals after two dofile reloads). Track everything registered here and
-- clear the previous run's set before re-appending.
local reload = _G.__aj_reload or {}
_G.__aj_reload = reload
-- Global (root-level) bindings re-apply at top level on every rc execution,
-- so clearing the previous run's set here is safe. Client default keys and
-- mousebuttons are signal-gated (request::default_*, emitted once per
-- process at client scanning) — stripping them here would remove them
-- forever because the signal never re-fires on reload. That exact bug
-- killed Mod4+Shift+c after a dofile; their cleanup lives inside the
-- setters instead (2026-09-27).
for _, k in ipairs(reload.global_keys or {}) do awful.keyboard.remove_global_keybinding(k) end
for _, b in ipairs(reload.global_mouse or {}) do awful.mouse.remove_global_mousebinding(b) end
reload.global_keys = {}
reload.global_mouse = {}

local function set_global_keybindings(keys)
    awful.keyboard.append_global_keybindings(keys)
    for _, k in ipairs(keys) do reload.global_keys[#reload.global_keys + 1] = k end
end

local function set_client_keybindings(keys)
    -- Signal-gated: remove-then-append must only run when this setter
    -- actually executes, never on bare rc re-execution.
    for _, k in ipairs(reload.client_keys or {}) do awful.keyboard.remove_client_keybinding(k) end
    reload.client_keys = {}
    awful.keyboard.append_client_keybindings(keys)
    for _, k in ipairs(keys) do reload.client_keys[#reload.client_keys + 1] = k end
end

local function set_global_mousebindings(buttons)
    awful.mouse.append_global_mousebindings(buttons)
    for _, b in ipairs(buttons) do reload.global_mouse[#reload.global_mouse + 1] = b end
end

local function set_client_mousebindings(buttons)
    -- Signal-gated: see set_client_keybindings.
    for _, b in ipairs(reload.client_mouse or {}) do awful.mouse.remove_client_mousebinding(b) end
    reload.client_mouse = {}
    awful.mouse.append_client_mousebindings(buttons)
    for _, b in ipairs(buttons) do reload.client_mouse[#reload.client_mouse + 1] = b end
end

-- 30 tags: 9 digits + letters + F-keys, matching old config.
local win_num = 30
local win_keys = {
    "#10", "#11", "#12", "#13", "#14", "#15", "#16", "#17", "#18",
    "a", "b", "d", "e", "g", "i", "v", "y", "z",
    "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12"
}
local win_tags = {
    "1", "2", "3", "4", "5", "6", "7", "8", "9",
    "a", "b", "d", "e", "g", "i", "v", "y", "z",
    "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12"
}

-- Tag color categories: 7 hues x bright/dim = 14 colors.
-- Color encodes tag *category*, not active state (the white sel square marks that).
-- Index 0 = no color override (use theme defaults; no brightness dimension).
local tag_colors = {
    [0] = nil,  -- no override
    [1] = { bright = "#e74c3c", dim = "#743c3c", fg = "#fff0f0" },  -- red
    [2] = { bright = "#e67e22", dim = "#74583c", fg = "#fff3ea" },  -- orange
    [3] = { bright = "#f1c40f", dim = "#756a3c", fg = "#fffff0" },  -- yellow
    [4] = { bright = "#2ecc71", dim = "#3c7551", fg = "#f0fff5" },  -- green
    [5] = { bright = "#1abc9c", dim = "#3c655e", fg = "#f0fffb" },  -- teal
    [6] = { bright = "#3498db", dim = "#3c5875", fg = "#f0f5ff" },  -- blue
    [7] = { bright = "#9b59b6", dim = "#5a3c75", fg = "#f5f0ff" },  -- purple
}
local color_names = { "red", "orange", "yellow", "green", "teal", "blue", "purple" }

-- Debug log helper: writes to /tmp/awesome_debug.log
local function debug_log(msg)
    local f = io.open("/tmp/awesome_debug.log", "a")
    if f then
        f:write(os.date("%H:%M:%S") .. " " .. msg .. "\n")
        f:close()
    end
end

debug_log("awesomerc.lua loaded (awesome-j)")

-- Wrap awful.widget.common.list_update to re-apply per-tag colors
-- after the default theme pass overwrites them.
local awcommon = require("awful.widget.common")
local default_list_update = awcommon.list_update
local function taglist_update_with_colors(w, buttons, label, data, objects)
    default_list_update(w, buttons, label, data, objects)
    for _, t in ipairs(objects) do
        local cache = data[t]
        if cache and cache.bgb then
            local ci = t.color_index or 0
            local colors = tag_colors[ci]
            if colors then
                cache.bgb:set_bg(t.color_bright ~= false and colors.bright or colors.dim)
                cache.bgb:set_fg(colors.fg)
            end
        end
    end
end
-- }}}

-- {{{ Menu
-- @DOC_MENU@
-- Create a launcher widget and a main menu
myawesomemenu = {
   { "hotkeys", function() hotkeys_popup.show_help(nil, awful.screen.focused()) end },
   { "manual", terminal .. " -e man awesome" },
   { "edit config", editor_cmd .. " " .. awesome.conffile },
   { "restart", awesome.restart },
   { "quit", function() awesome.quit() end },
}

local menu_awesome = { "awesome", myawesomemenu, beautiful.awesome_icon }
local menu_terminal = { "open terminal", terminal }

if has_fdo then
    mymainmenu = freedesktop.menu.build({
        before = { menu_awesome },
        after  = { menu_terminal }
    })
else
    mymainmenu = awful.menu({
        items = {
                  menu_awesome,
                  { "Debian", debian.menu.Debian_menu.Debian },
                  menu_terminal,
                }
    })
end

mylauncher = awful.widget.launcher({ image = beautiful.awesome_icon,
                                     menu = mymainmenu })

-- Menubar configuration
menubar.utils.terminal = terminal -- Set the terminal for applications that require it
-- }}}

-- {{{ Tag layout
-- @DOC_LAYOUT@
-- Table of layouts to cover with awful.layout.inc, order matters.
-- Migrated from old config: disabled floating, spiral, magnifier, corners.
tag.connect_signal("request::default_layouts", function()
    -- Reload safety: clear the previous set before appending (layouts are
    -- only re-requested when new tags appear, so existing tags keep whatever
    -- is registered between runs — no emptiness window).
    for _, l in ipairs(reload.layouts or {}) do awful.layout.remove_default_layout(l) end
    reload.layouts = {}
    local layouts = {
        awful.layout.suit.tile,
        awful.layout.suit.tile.left,
        awful.layout.suit.tile.bottom,
        awful.layout.suit.tile.top,
        awful.layout.suit.fair,
        awful.layout.suit.fair.horizontal,
        awful.layout.suit.max,
    }
    awful.layout.append_default_layouts(layouts)
    for _, l in ipairs(layouts) do reload.layouts[#reload.layouts + 1] = l end
end)
-- }}}

-- {{{ Wallpaper
-- @DOC_WALLPAPER@
-- Wallpaper: black_flower.png shipped in the installed themes dir.
-- Uses gears.wallpaper.maximized to stretch-fill the screen.
screen.connect_signal("request::wallpaper", function(s)
    gears.wallpaper.maximized(
        gears.filesystem.get_themes_dir() .. "default/black_flower.png",
        s, true
    )
end)
-- }}}

-- {{{ Wibar

-- Keyboard map indicator and switcher
mykeyboardlayout = awful.widget.keyboardlayout()

-- Create a textclock widget
mytextclock = wibox.widget.textclock()

-- @DOC_FOR_EACH_SCREEN@
screen.connect_signal("request::desktop_decoration", function(s)
    -- Reload safety: never stack a second decoration set / wibar on a screen
    -- that already has one. Widget changes need an exec restart (Ctrl+Mod4+r).
    if s.mywibox then return end

    -- Each screen has its own tag table.
    -- Migrated from old config: 30 tags instead of 9.
    -- Reload safety: skip re-creating tags on in-process re-execution so
    -- their runtime color state (color_index/color_bright) survives.
    if #s.tags == 0 then
        awful.tag(win_tags, s, awful.layout.layouts[1])

        -- Initialize color group index on each tag.
        for _, t in ipairs(s.tags) do
            t.color_index = 0
        end
        debug_log("screen " .. s.index .. ": " .. #s.tags .. " tags initialized")
    end

    -- Create a promptbox for each screen
    s.mypromptbox = awful.widget.prompt()

    -- Create an imagebox widget which will contain an icon indicating which layout we are using.
    -- We need one layoutbox per screen.
    s.mylayoutbox = awful.widget.layoutbox {
        screen  = s,
        buttons = {
            awful.button({ }, 1, function () awful.layout.inc( 1) end),
            awful.button({ }, 3, function () awful.layout.inc(-1) end),
            awful.button({ }, 4, function () awful.layout.inc( 1) end),
            awful.button({ }, 5, function () awful.layout.inc(-1) end),
        }
    }

    -- Create a taglist widget with color group support
    s.mytaglist = awful.widget.taglist {
        screen          = s,
        filter          = awful.widget.taglist.filter.all,
        update_function = taglist_update_with_colors,
        buttons = {
            awful.button({ }, 1, function(t) t:view_only() end),
            awful.button({ modkey }, 1, function(t)
                                            if client.focus then
                                                client.focus:move_to_tag(t)
                                            end
                                        end),
            awful.button({ }, 3, awful.tag.viewtoggle),
            awful.button({ modkey }, 3, function(t)
                                            if client.focus then
                                                client.focus:toggle_tag(t)
                                            end
                                        end),
            awful.button({ }, 4, function(t) awful.tag.viewprev(t.screen) end),
            awful.button({ }, 5, function(t) awful.tag.viewnext(t.screen) end),
        }
    }

    -- @TASKLIST_BUTTON@
    -- Create a tasklist widget
    s.mytasklist = awful.widget.tasklist {
        screen  = s,
        filter  = awful.widget.tasklist.filter.currenttags,
        buttons = {
            awful.button({ }, 1, function (c)
                c:activate { context = "tasklist", action = "toggle_minimization" }
            end),
            awful.button({ }, 3, function() awful.menu.client_list { theme = { width = 250 } } end),
            awful.button({ }, 4, function() awful.client.focus.byidx(-1) end),
            awful.button({ }, 5, function() awful.client.focus.byidx( 1) end),
        }
    }

    -- @DOC_WIBAR@
    -- Create the wibox
    s.mywibox = awful.wibar {
        position = "top",
        screen   = s,
        -- @DOC_SETUP_WIDGETS@
        widget   = {
            layout = wibox.layout.align.horizontal,
            { -- Left widgets
                layout = wibox.layout.fixed.horizontal,
                mylauncher,
                s.mytaglist,
                s.mypromptbox,
            },
            s.mytasklist, -- Middle widgets
            { -- Right widgets
                layout = wibox.layout.fixed.horizontal,
                mykeyboardlayout,
                wibox.widget.systray(),
                mytextclock,
                s.mylayoutbox,
            },
        }
    }
end)

-- }}}

-- {{{ Mouse bindings
-- @DOC_ROOT_BUTTONS@
set_global_mousebindings({
    awful.button({ }, 3, function () mymainmenu:toggle() end),
    awful.button({ }, 4, awful.tag.viewprev),
    awful.button({ }, 5, awful.tag.viewnext),
})
-- }}}

-- {{{ Key bindings
-- @DOC_GLOBAL_KEYBINDINGS@

-- General Awesome keys
set_global_keybindings({
    awful.key({ modkey,           }, "s",      hotkeys_popup.show_help,
              {description="show help", group="awesome"}),
    awful.key({ modkey,           }, "w", function () mymainmenu:show() end,
              {description = "show main menu", group = "awesome"}),
    awful.key({ modkey, "Control" }, "r", awesome.restart,
              {description = "reload awesome", group = "awesome"}),
    awful.key({ modkey, "Shift"   }, "q", awesome.quit,
              {description = "quit awesome", group = "awesome"}),
    awful.key({ modkey }, "x",
              function ()
                  awful.prompt.run {
                    prompt       = "Run Lua code: ",
                    textbox      = awful.screen.focused().mypromptbox.widget,
                    exe_callback = awful.util.eval,
                    history_path = awful.util.get_cache_dir() .. "/history_eval"
                  }
              end,
              {description = "lua execute prompt", group = "awesome"}),
    awful.key({ modkey,           }, "Return", function () awful.spawn(terminal) end,
              {description = "open a terminal", group = "launcher"}),
    awful.key({ modkey },            "r",     function () awful.screen.focused().mypromptbox:run() end,
              {description = "run prompt", group = "launcher"}),
    awful.key({ modkey }, "p", function() menubar.show() end,
              {description = "show the menubar", group = "launcher"}),
})

-- Tags related keybindings
set_global_keybindings({
    awful.key({ modkey,           }, "Left",   awful.tag.viewprev,
              {description = "view previous", group = "tag"}),
    awful.key({ modkey,           }, "Right",  awful.tag.viewnext,
              {description = "view next", group = "tag"}),
    awful.key({ modkey,           }, "Escape", awful.tag.history.restore,
              {description = "go back", group = "tag"}),
    -- Tag color cycling: Ctrl+Shift+z
    awful.key({ "Control", "Shift" }, "z",
        function ()
            debug_log("Ctrl+Shift+z triggered")
            local s = awful.screen.focused()
            local t = s and s.selected_tag
            if not t then return end
            local old_ci = t.color_index or 0
            local new_ci = (old_ci + 1) % 8
            t.color_index = new_ci
            debug_log("tag '" .. t.name .. "' color_index: " .. old_ci .. " -> " .. new_ci)
            naughty.notification {
                title   = "Tag Color",
                message = "Tag '" .. t.name .. "' color: " .. (
                    new_ci == 0 and "none" or color_names[new_ci] or "?"
                ),
                timeout = 1,
            }
            -- Force taglist refresh
            t.name = t.name
        end,
        {description = "cycle tag color group", group = "tag"}),
    -- Tag brightness toggle: Ctrl+Shift+x (category dimension, orthogonal to hue)
    awful.key({ "Control", "Shift" }, "x",
        function ()
            debug_log("Ctrl+Shift+x triggered")
            local s = awful.screen.focused()
            local t = s and s.selected_tag
            if not t then return end
            local ci = t.color_index or 0
            if not tag_colors[ci] then
                naughty.notification {
                    title   = "Tag Color",
                    message = "Tag '" .. t.name .. "' has no color category (theme default)",
                    timeout = 1,
                }
                return
            end
            local old_bright = t.color_bright ~= false
            t.color_bright = not old_bright
            debug_log("tag '" .. t.name .. "' bright: " .. tostring(old_bright) ..
                " -> " .. tostring(t.color_bright))
            naughty.notification {
                title   = "Tag Color",
                message = "Tag '" .. t.name .. "': " .. (color_names[ci] or "?") ..
                    " " .. (t.color_bright and "bright" or "dim"),
                timeout = 1,
            }
            -- Force taglist refresh
            t.name = t.name
        end,
        {description = "toggle tag color brightness", group = "tag"}),
})

-- Focus related keybindings
set_global_keybindings({
    awful.key({ modkey,           }, "j",
        function ()
            awful.client.focus.byidx( 1)
        end,
        {description = "focus next by index", group = "client"}
    ),
    awful.key({ modkey,           }, "k",
        function ()
            awful.client.focus.byidx(-1)
        end,
        {description = "focus previous by index", group = "client"}
    ),
    awful.key({ modkey,           }, "Tab",
        function ()
            awful.client.focus.history.previous()
            if client.focus then
                client.focus:raise()
            end
        end,
        {description = "go back", group = "client"}),
    awful.key({ modkey, "Control" }, "j", function () awful.screen.focus_relative( 1) end,
              {description = "focus the next screen", group = "screen"}),
    awful.key({ modkey, "Control" }, "k", function () awful.screen.focus_relative(-1) end,
              {description = "focus the previous screen", group = "screen"}),
    awful.key({ modkey, "Control" }, "n",
              function ()
                  local c = awful.client.restore()
                  -- Focus restored client
                  if c then
                    c:activate { raise = true, context = "key.unminimize" }
                  end
              end,
              {description = "restore minimized", group = "client"}),
})

-- Layout related keybindings
set_global_keybindings({
    awful.key({ modkey, "Shift"   }, "j", function () awful.client.swap.byidx(  1)    end,
              {description = "swap with next client by index", group = "client"}),
    awful.key({ modkey, "Shift"   }, "k", function () awful.client.swap.byidx( -1)    end,
              {description = "swap with previous client by index", group = "client"}),
    awful.key({ modkey,           }, "u", awful.client.urgent.jumpto,
              {description = "jump to urgent client", group = "client"}),
    awful.key({ modkey,           }, "l",     function () awful.tag.incmwfact( 0.05)          end,
              {description = "increase master width factor", group = "layout"}),
    awful.key({ modkey,           }, "h",     function () awful.tag.incmwfact(-0.05)          end,
              {description = "decrease master width factor", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "h",     function () awful.tag.incnmaster( 1, nil, true) end,
              {description = "increase the number of master clients", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "l",     function () awful.tag.incnmaster(-1, nil, true) end,
              {description = "decrease the number of master clients", group = "layout"}),
    awful.key({ modkey, "Control" }, "h",     function () awful.tag.incncol( 1, nil, true)    end,
              {description = "increase the number of columns", group = "layout"}),
    awful.key({ modkey, "Control" }, "l",     function () awful.tag.incncol(-1, nil, true)    end,
              {description = "decrease the number of columns", group = "layout"}),
    awful.key({ modkey,           }, "space", function () awful.layout.inc( 1)                end,
              {description = "select next", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "space", function () awful.layout.inc(-1)                end,
              {description = "select previous", group = "layout"}),
})

-- Migrated from old config: 30 tag keybindings (digit+letter+Fkeys)
-- using the same keycode/keysym pattern as the old config.
local tag_keys_global = {}
for i = 1, win_num do
    table.insert(tag_keys_global,
        awful.key({ modkey }, win_keys[i],
            function ()
                local screen = awful.screen.focused()
                local tag = screen.tags[i]
                if tag then tag:view_only() end
            end,
            {description = "view tag #"..i, group = "tag"})
    )
    table.insert(tag_keys_global,
        awful.key({ modkey, "Control" }, win_keys[i],
            function ()
                local screen = awful.screen.focused()
                local tag = screen.tags[i]
                if tag then awful.tag.viewtoggle(tag) end
            end,
            {description = "toggle tag #" .. i, group = "tag"})
    )
    table.insert(tag_keys_global,
        awful.key({ modkey, "Shift" }, win_keys[i],
            function ()
                if client.focus then
                    local tag = client.focus.screen.tags[i]
                    if tag then client.focus:move_to_tag(tag) end
                end
            end,
            {description = "move focused client to tag #"..i, group = "tag"})
    )
    table.insert(tag_keys_global,
        awful.key({ modkey, "Control", "Shift" }, win_keys[i],
            function ()
                if client.focus then
                    local tag = client.focus.screen.tags[i]
                    if tag then client.focus:toggle_tag(tag) end
                end
            end,
            {description = "toggle focused client on tag #" .. i, group = "tag"})
    )
end
set_global_keybindings(tag_keys_global)

-- @DOC_CLIENT_BUTTONS@
client.connect_signal("request::default_mousebindings", function()
    set_client_mousebindings({
        awful.button({ }, 1, function (c)
            c:activate { context = "mouse_click" }
        end),
        awful.button({ modkey }, 1, function (c)
            c:activate { context = "mouse_click", action = "mouse_move"  }
        end),
        awful.button({ modkey }, 3, function (c)
            c:activate { context = "mouse_click", action = "mouse_resize"}
        end),
    })
end)

-- @DOC_CLIENT_KEYBINDINGS@
client.connect_signal("request::default_keybindings", function()
    set_client_keybindings({
        awful.key({ modkey,           }, "f",
            function (c)
                c.fullscreen = not c.fullscreen
                c:raise()
            end,
            {description = "toggle fullscreen", group = "client"}),
        awful.key({ modkey, "Shift"   }, "c",      function (c) c:kill()                         end,
                {description = "close", group = "client"}),
        awful.key({ modkey, "Control" }, "space",  awful.client.floating.toggle                     ,
                {description = "toggle floating", group = "client"}),
        awful.key({ modkey, "Control" }, "Return", function (c) c:swap(awful.client.getmaster()) end,
                {description = "move to master", group = "client"}),
        awful.key({ modkey,           }, "o",      function (c) c:move_to_screen()               end,
                {description = "move to screen", group = "client"}),
        awful.key({ modkey,           }, "t",      function (c) c.ontop = not c.ontop            end,
                {description = "toggle keep on top", group = "client"}),
        awful.key({ modkey,           }, "n",
            function (c)
                -- The client currently has the input focus, so it cannot be
                -- minimized, since minimized clients can't have the focus.
                c.minimized = true
            end ,
            {description = "minimize", group = "client"}),
        awful.key({ modkey,           }, "m",
            function (c)
                c.maximized = not c.maximized
                c:raise()
            end ,
            {description = "(un)maximize", group = "client"}),
        awful.key({ modkey, "Control" }, "m",
            function (c)
                c.maximized_vertical = not c.maximized_vertical
                c:raise()
            end ,
            {description = "(un)maximize vertically", group = "client"}),
        awful.key({ modkey, "Shift"   }, "m",
            function (c)
                c.maximized_horizontal = not c.maximized_horizontal
                c:raise()
            end ,
            {description = "(un)maximize horizontally", group = "client"}),
    })
end)

-- }}}

-- {{{ Rules
-- Rules to apply to new clients.
-- @DOC_RULES@
ruled.client.connect_signal("request::rules", function()
    -- @DOC_GLOBAL_RULE@
    -- All clients will match this rule.
    ruled.client.append_rule {
        id         = "global",
        rule       = { },
        properties = {
            border_width = beautiful.border_width,
            border_color = beautiful.border_normal,
            focus        = awful.client.focus.filter,
            raise        = true,
            screen       = awful.screen.preferred,
            placement    = awful.placement.no_overlap+awful.placement.no_offscreen
        }
    }

    -- @DOC_FLOATING_RULE@
    -- Floating clients.
    ruled.client.append_rule {
        id       = "floating",
        rule_any = {
            instance = { "copyq", "pinentry" },
            class    = {
                "Arandr", "Blueman-manager", "Gpick", "Kruler", "Sxiv",
                "Tor Browser", "Wpa_gui", "veromix", "xtightvncviewer"
            },
            name    = {
                "Event Tester",  -- xev.
            },
            role    = {
                "AlarmWindow",    -- Thunderbird's calendar.
                "ConfigManager",  -- Thunderbird's about:config.
                "pop-up",         -- e.g. Google Chrome's (detached) Developer Tools.
            }
        },
        properties = { floating = true }
    }

    -- Migrated from old config: titlebars disabled.
    ruled.client.append_rule {
        id         = "titlebars",
        rule_any   = { type = { "normal", "dialog" } },
        properties = { titlebars_enabled = false }
    }
end)
-- }}}

-- {{{ Titlebars
-- @DOC_TITLEBARS@
-- Add a titlebar if titlebars_enabled is set to true in the rules.
client.connect_signal("request::titlebars", function(c)
    -- buttons for the titlebar
    local buttons = {
        awful.button({ }, 1, function()
            c:activate { context = "titlebar", action = "mouse_move"  }
        end),
        awful.button({ }, 3, function()
            c:activate { context = "titlebar", action = "mouse_resize"}
        end),
    }

    awful.titlebar(c).widget = {
        { -- Left
            awful.titlebar.widget.iconwidget(c),
            buttons = buttons,
            layout  = wibox.layout.fixed.horizontal
        },
        { -- Middle
            { -- Title
                halign = "center",
                widget = awful.titlebar.widget.titlewidget(c)
            },
            buttons = buttons,
            layout  = wibox.layout.flex.horizontal
        },
        { -- Right
            awful.titlebar.widget.floatingbutton (c),
            awful.titlebar.widget.maximizedbutton(c),
            awful.titlebar.widget.stickybutton   (c),
            awful.titlebar.widget.ontopbutton    (c),
            awful.titlebar.widget.closebutton    (c),
            layout = wibox.layout.fixed.horizontal()
        },
        layout = wibox.layout.align.horizontal
    }
end)
-- }}}

-- {{{ Notifications

ruled.notification.connect_signal('request::rules', function()
    -- All notifications will match this rule.
    ruled.notification.append_rule {
        rule       = { },
        properties = {
            screen           = awful.screen.preferred,
            implicit_timeout = 5,
        }
    }
end)

naughty.connect_signal("request::display", function(n)
    naughty.layout.box { notification = n }
end)

-- }}}

-- Enable sloppy focus, so that focus follows mouse.
client.connect_signal("mouse::enter", function(c)
    c:activate { context = "mouse_enter", raise = false }
end)

client.connect_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)

-- Migrated from old config: prevent clients from being unreachable after
-- screen count changes.
client.connect_signal("manage", function (c)
    if awesome.startup
      and not c.size_hints.user_position
      and not c.size_hints.program_position then
        awful.placement.no_offscreen(c)
    end
end)

-- Re-set wallpaper when a screen's geometry changes (e.g. different resolution).
screen.connect_signal("property::geometry", function(s)
    screen.emit_signal("request::wallpaper", s)
end)
