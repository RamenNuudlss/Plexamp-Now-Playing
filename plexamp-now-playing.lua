--[[
  Plexamp Now Playing for OBS  (v2)
  ---------------------------------
  Tools -> Scripts -> "+" -> pick this file.
  Keep these next to it:  plexamp-now-playing.html  and  plexamp-style-studio.html

  - Writes config.json / config.js next to this script; the overlay picks up changes live.
  - "Add overlay to current scene" creates a Browser Source called "Plexamp Now Playing".
  - The Style Studio (a web page) can send looks straight to OBS through obs-websocket,
    or you can paste a style code into the Style Studio box below.
  - Presets: save your own looks by name (presets.json next to this script) and switch
    between them from the panel, from the Style Studio or with hotkeys.
  - Hotkeys (Settings -> Hotkeys): toggle Plexamp's visualizer, show/hide the overlay,
    next / previous theme, next / previous preset, Preset 1 to 10.

  Only checkboxes, sliders, dropdowns, plain text and buttons are used in this panel:
  OBS 32.2.2's Scripts window crashes on color pickers and password boxes.
]]

local obs = obslua

local SCRIPT_DIR   = script_path()
local HTML_FILE    = "plexamp-now-playing.html"
local STUDIO_FILE  = "plexamp-style-studio.html"
local OVERLAY_NAME = "Plexamp Now Playing"
local VIS_NAME     = "Plexamp Visualizer"

-- theme list (kept in sync with the themes in plexamp-now-playing.html)
local THEMES = {
  { id = "ultrablur", name = "Ultrablur", group = "Modern", size = {680, 220}, sizes = {["tall"] = {360, 540}, ["edge"] = {700, 210}, ["float"] = {700, 250}}, variants = {{"card", "Card"}, {"tall", "Tall"}, {"edge", "Edge-to-edge cover"}, {"float", "Floating cover"}},
    defaults = {["colors"] = "album", ["background"] = "album", ["enter"] = "slide-left", ["change"] = "slide", ["progress"] = "bar", ["artShape"] = "rounded"}, vdefaults = {} },
  { id = "slim", name = "Slim bar", group = "Modern", size = {720, 96}, sizes = {}, variants = {{"album", "Album colors"}, {"dark", "Dark"}, {"light", "Light"}},
    defaults = {["colors"] = "album", ["background"] = "album", ["enter"] = "slide-up", ["change"] = "slide", ["progress"] = "line", ["viz"] = "bars"}, vdefaults = {} },
  { id = "island", name = "Island", group = "Modern", size = {640, 150}, sizes = {}, variants = {{"auto", "Opens on song change"}, {"open", "Always open"}, {"compact", "Always compact"}},
    defaults = {["colors"] = "album", ["enter"] = "pop", ["change"] = "signature", ["progress"] = "bar", ["artShape"] = "rounded", ["textFx"] = "none"}, vdefaults = {} },
  { id = "spotlight", name = "Spotlight", group = "Modern", size = {460, 460}, sizes = {["poster"] = {420, 580}, ["circle"] = {420, 540}}, variants = {{"square", "Square"}, {"poster", "Poster"}, {"circle", "Round cover"}},
    defaults = {["colors"] = "album", ["background"] = "album", ["enter"] = "zoom", ["change"] = "fade", ["progress"] = "line", ["artShape"] = "rounded"}, vdefaults = {["circle"] = {["progress"] = "ring", ["artShape"] = "circle"}, ["poster"] = {["progress"] = "bar"}} },
  { id = "minimal", name = "Minimal", group = "Modern", size = {760, 160}, sizes = {}, variants = {{"left", "Left aligned"}, {"right", "Right aligned"}, {"center", "Centered"}},
    defaults = {["colors"] = "album", ["background"] = "none", ["enter"] = "fade", ["change"] = "blur", ["progress"] = "line", ["artShape"] = "rounded", ["textFx"] = "blur"}, vdefaults = {["center"] = {["artShape"] = "hidden"}} },
  { id = "lowerthird", name = "Lower third", group = "Broadcast", size = {940, 160}, sizes = {}, variants = {{"dark", "Dark"}, {"light", "Light"}, {"accent", "Accent color"}},
    defaults = {["colors"] = "album", ["enter"] = "wipe", ["change"] = "wipe", ["progress"] = "line", ["artShape"] = "square", ["textCase"] = "upper"}, vdefaults = {} },
  { id = "vinyl", name = "Vinyl", group = "Physical media", size = {800, 250}, sizes = {}, variants = {{"black", "Black vinyl"}, {"color", "Colored vinyl"}, {"splatter", "Splatter"}, {"picture", "Picture disc"}},
    defaults = {["colors"] = "album", ["background"] = "album", ["enter"] = "slide-left", ["change"] = "signature", ["progress"] = "bar", ["artShape"] = "square"}, vdefaults = {} },
  { id = "cassette", name = "Cassette", group = "Physical media", size = {600, 384}, sizes = {}, variants = {{"smoke", "Smoke shell"}, {"black", "Black shell"}, {"white", "White shell"}, {"aqua", "Clear aqua"}, {"red", "Red shell"}, {"artlabel", "Album-art label"}},
    defaults = {["colors"] = "album", ["enter"] = "drop", ["change"] = "signature", ["progress"] = "none", ["artShape"] = "square", ["textFx"] = "none"}, vdefaults = {} },
  { id = "cd", name = "CD", group = "Physical media", size = {780, 260}, sizes = {}, variants = {{"printed", "Printed disc"}, {"shiny", "Rainbow side"}, {"discOnly", "Disc only"}},
    defaults = {["colors"] = "album", ["background"] = "album", ["enter"] = "slide-left", ["change"] = "signature", ["progress"] = "bar", ["artShape"] = "square"}, vdefaults = {} },
  { id = "polaroid", name = "Polaroid", group = "Physical media", size = {460, 540}, sizes = {}, variants = {{"stack", "Photo pile"}, {"single", "Single photo"}, {"taped", "Taped to the wall"}},
    defaults = {["colors"] = "album", ["enter"] = "drop", ["change"] = "signature", ["progress"] = "none", ["artShape"] = "square"}, vdefaults = {} },
  { id = "ticket", name = "Ticket", group = "Physical media", size = {840, 290}, sizes = {}, variants = {{"cream", "Cream paper"}, {"white", "White paper"}, {"holo", "Holographic foil"}, {"kraft", "Kraft paper"}},
    defaults = {["colors"] = "album", ["enter"] = "slide-right", ["change"] = "signature", ["progress"] = "none", ["artShape"] = "square", ["textCase"] = "upper"}, vdefaults = {} },
  { id = "receipt", name = "Receipt", group = "Physical media", size = {380, 600}, sizes = {["long"] = {380, 800}}, variants = {{"thermal", "Thermal paper"}, {"faded", "Old and faded"}, {"long", "Long receipt"}},
    defaults = {["colors"] = "album", ["enter"] = "slide-up", ["change"] = "signature", ["progress"] = "none", ["textCase"] = "upper"}, vdefaults = {} },
  { id = "retroamp", name = "Retro Amp", group = "Retro tech", size = {660, 250}, sizes = {}, variants = {{"classic", "Classic gray"}, {"midnight", "Midnight blue"}, {"gold", "Brushed gold"}, {"album", "Album skin"}},
    defaults = {["colors"] = "own", ["enter"] = "slide-left", ["change"] = "none", ["progress"] = "bar", ["viz"] = "blocks", ["artShape"] = "square"}, vdefaults = {} },
  { id = "terminal", name = "Terminal", group = "Retro tech", size = {700, 270}, sizes = {}, variants = {{"green", "Green phosphor"}, {"amber", "Amber"}, {"modern", "Modern dark"}, {"paper", "Light"}},
    defaults = {["colors"] = "own", ["enter"] = "fade", ["change"] = "signature", ["progress"] = "none", ["artShape"] = "hidden"}, vdefaults = {} },
  { id = "carstereo", name = "Car stereo", group = "Retro tech", size = {760, 170}, sizes = {}, variants = {{"amber", "Amber"}, {"ice", "Ice blue"}, {"green", "Green"}, {"red", "Red"}, {"white", "White"}},
    defaults = {["colors"] = "own", ["enter"] = "slide-up", ["change"] = "none", ["progress"] = "none", ["artShape"] = "hidden"}, vdefaults = {} },
  { id = "splitflap", name = "Split-flap board", group = "Retro tech", size = {990, 216}, sizes = {}, variants = {{"classic", "Classic black"}, {"amber", "Amber letters"}, {"station", "Station blue"}, {"bright", "White tiles"}},
    defaults = {["colors"] = "own", ["enter"] = "fade", ["change"] = "signature", ["progress"] = "none", ["artShape"] = "square", ["textCase"] = "upper"}, vdefaults = {} },
  { id = "pixel", name = "Pixel RPG", group = "Retro tech", size = {760, 250}, sizes = {}, variants = {{"classic", "Classic blue"}, {"pocket", "Pocket green"}, {"night", "Black and white"}, {"album", "Album colors"}},
    defaults = {["colors"] = "album", ["enter"] = "pop", ["change"] = "signature", ["progress"] = "none", ["artShape"] = "square"}, vdefaults = {} },
  { id = "neon", name = "Neon sign", group = "Night", size = {780, 300}, sizes = {}, variants = {{"brick", "Brick wall"}, {"dark", "Dark wall"}, {"none", "No wall"}},
    defaults = {["colors"] = "own", ["enter"] = "fade", ["change"] = "signature", ["progress"] = "line", ["artShape"] = "rounded", ["textCase"] = "normal"}, vdefaults = {} },
  { id = "synthwave", name = "Synthwave", group = "Night", size = {800, 300}, sizes = {}, variants = {{"sunset", "Sunset"}, {"night", "Midnight"}, {"miami", "Miami"}},
    defaults = {["colors"] = "own", ["enter"] = "zoom", ["change"] = "fade", ["progress"] = "line", ["artShape"] = "circle", ["textCase"] = "normal"}, vdefaults = {} },
  { id = "aero", name = "Aero", group = "Y2K", size = {700, 236}, sizes = {}, variants = {{"aqua", "Aqua"}, {"lime", "Lime"}, {"bubblegum", "Bubblegum"}, {"silver", "Silver"}},
    defaults = {["colors"] = "own", ["enter"] = "pop", ["change"] = "zoom", ["progress"] = "bar", ["artShape"] = "rounded"}, vdefaults = {} },
  { id = "brutal", name = "Brutalist", group = "Graphic", size = {760, 260}, sizes = {}, variants = {{"paper", "Paper"}, {"ink", "Ink"}, {"album", "Album color"}},
    defaults = {["colors"] = "album", ["enter"] = "drop", ["change"] = "rise", ["progress"] = "bar", ["artShape"] = "square", ["textCase"] = "upper"}, vdefaults = {} },
  { id = "lyrics", name = "Lyrics", group = "Karaoke", size = {920, 300}, sizes = {["subtitle"] = {920, 150}}, variants = {{"karaoke", "Three lines"}, {"single", "One big line"}, {"subtitle", "TV subtitles"}},
    defaults = {["colors"] = "album", ["background"] = "none", ["enter"] = "fade", ["change"] = "fade", ["progress"] = "line", ["lyrics"] = "karaoke", ["artShape"] = "rounded"}, vdefaults = {} },
  { id = "visualizer", name = "Visualizer", group = "Karaoke", size = {820, 260}, sizes = {["radial"] = {480, 480}}, variants = {{"bars", "Bars"}, {"mirror", "Mirrored"}, {"line", "Wave"}, {"radial", "Round"}},
    defaults = {["colors"] = "album", ["background"] = "album", ["enter"] = "zoom", ["change"] = "slide", ["progress"] = "line", ["artShape"] = "rounded"}, vdefaults = {} },
}
local STYLE_KEYS = {"colors", "accent", "bg", "ink", "font", "textSize", "textCase", "corners", "opacity", "background", "ambient", "effect", "textFx", "enter", "change", "artShape", "artMotion", "progress", "viz", "react", "lyrics", "marquee", "showAlbum", "showYear", "showQuality", "showTimes", "showEq", "showGenre", "showDevice", "showRating", "showPlays", "label"}
local STYLE_BUILTIN = {["colors"] = "album", ["accent"] = "", ["bg"] = "", ["ink"] = "", ["font"] = "theme", ["textSize"] = "m", ["textCase"] = "normal", ["corners"] = "theme", ["opacity"] = 100, ["background"] = "album", ["ambient"] = "none", ["effect"] = "none", ["textFx"] = "none", ["enter"] = "slide-left", ["change"] = "slide", ["artShape"] = "rounded", ["artMotion"] = "none", ["progress"] = "bar", ["viz"] = "none", ["react"] = "subtle", ["lyrics"] = "off", ["marquee"] = "normal", ["showAlbum"] = true, ["showYear"] = true, ["showQuality"] = true, ["showTimes"] = true, ["showEq"] = true, ["showGenre"] = false, ["showDevice"] = false, ["showRating"] = false, ["showPlays"] = false, ["label"] = ""}
local OPTIONS = {
  colors = {{"theme", "Theme default"}, {"album", "From the album"}, {"own", "Theme's own colors"}, {"custom", "Custom (hex codes)"}, {"sunset", "Sunset"}, {"ocean", "Ocean"}, {"forest", "Forest"}, {"candy", "Candy"}, {"ember", "Ember"}, {"ice", "Ice"}, {"grape", "Grape"}, {"matcha", "Matcha"}, {"gold", "Gold"}, {"mono", "Mono"}},
  font = {{"theme", "Theme default"}, {"Sora", "Sora"}, {"Figtree", "Figtree"}, {"Manrope", "Manrope"}, {"Outfit", "Outfit"}, {"Bricolage Grotesque", "Bricolage Grotesque"}, {"Space Grotesk", "Space Grotesk"}, {"Syne", "Syne"}, {"Unbounded", "Unbounded"}, {"Archivo", "Archivo"}, {"Archivo Black", "Archivo Black"}, {"Barlow Condensed", "Barlow Condensed"}, {"Oswald", "Oswald"}, {"League Gothic", "League Gothic"}, {"Fraunces", "Fraunces"}, {"Instrument Serif", "Instrument Serif"}, {"Instrument Sans", "Instrument Sans"}, {"DM Serif Display", "DM Serif Display"}, {"Caveat", "Caveat"}, {"Permanent Marker", "Permanent Marker"}, {"Courier Prime", "Courier Prime"}, {"JetBrains Mono", "JetBrains Mono"}, {"Space Mono", "Space Mono"}, {"VT323", "VT323"}, {"Silkscreen", "Silkscreen"}, {"Pixelify Sans", "Pixelify Sans"}, {"Press Start 2P", "Press Start 2P"}, {"Tilt Neon", "Tilt Neon"}, {"Neonderthaw", "Neonderthaw"}, {"Monoton", "Monoton"}, {"Righteous", "Righteous"}, {"Mr Dafoe", "Mr Dafoe"}, {"Varela Round", "Varela Round"}, {"Bungee", "Bungee"}, {"Rubik Mono One", "Rubik Mono One"}, {"System", "System font"}},
  textSize = {{"s", "Small"}, {"m", "Medium"}, {"l", "Large"}, {"xl", "Extra large"}},
  textCase = {{"theme", "Theme default"}, {"normal", "As written"}, {"upper", "UPPERCASE"}, {"lower", "lowercase"}},
  corners = {{"theme", "Theme default"}, {"square", "Square"}, {"soft", "Soft"}, {"round", "Round"}, {"pill", "Extra round"}},
  background = {{"theme", "Theme default"}, {"album", "Album colors"}, {"art", "Blurred album art"}, {"glass", "Dark glass"}, {"solid", "Solid color"}, {"gradient", "Two-tone gradient"}, {"none", "Transparent"}},
  ambient = {{"theme", "Theme default"}, {"none", "None"}, {"flow", "Color flow"}, {"aurora", "Aurora"}, {"bokeh", "Bokeh lights"}, {"particles", "Floating dust"}, {"stars", "Starfield"}, {"rain", "Rain"}, {"snow", "Snow"}, {"waves", "Waves"}, {"grid", "Retro grid"}},
  effect = {{"theme", "Theme default"}, {"none", "None"}, {"glow", "Accent glow"}, {"vhs", "VHS tape"}, {"film", "8mm film"}, {"crt", "CRT screen"}, {"scanlines", "Scanlines"}, {"grain", "Film grain"}, {"holo", "Holographic"}, {"chromatic", "Chromatic split"}, {"noir", "Black & white"}},
  textFx = {{"theme", "Theme default"}, {"none", "None"}, {"scramble", "Scramble"}, {"typewriter", "Typewriter"}, {"glitch", "Glitch"}, {"wave", "Wave in"}, {"blur", "Blur in"}},
  enter = {{"theme", "Theme default"}, {"slide-left", "Slide from left"}, {"slide-right", "Slide from right"}, {"slide-up", "Slide up"}, {"slide-down", "Slide down"}, {"fade", "Fade"}, {"zoom", "Zoom"}, {"pop", "Pop"}, {"drop", "Drop & bounce"}, {"blur", "Blur"}, {"wipe", "Wipe"}, {"flip", "Flip"}, {"none", "Instant"}},
  change = {{"theme", "Theme default"}, {"signature", "Theme's signature move"}, {"slide", "Slide"}, {"rise", "Rise"}, {"fade", "Fade"}, {"zoom", "Zoom"}, {"blur", "Blur"}, {"wipe", "Wipe"}, {"flip", "Flip the cover"}, {"none", "None"}},
  artShape = {{"theme", "Theme default"}, {"square", "Square"}, {"rounded", "Rounded"}, {"circle", "Circle"}, {"hidden", "Hidden"}},
  artMotion = {{"theme", "Theme default"}, {"none", "None"}, {"float", "Float"}, {"tilt", "Tilt"}, {"pulse", "Pulse to the music"}, {"spin", "Spin"}, {"breathe", "Glow to the music"}},
  progress = {{"theme", "Theme default"}, {"bar", "Bar"}, {"line", "Thin line"}, {"waveform", "Waveform"}, {"blocks", "LED blocks"}, {"dots", "Dots"}, {"ring", "Ring around the cover"}, {"none", "Hidden"}},
  viz = {{"theme", "Theme default"}, {"none", "Off"}, {"bars", "Bars"}, {"mirror", "Mirrored bars"}, {"line", "Line"}, {"dots", "Dots"}, {"blocks", "LED blocks"}},
  react = {{"off", "Off"}, {"subtle", "Subtle"}, {"strong", "Strong"}},
  lyrics = {{"theme", "Theme default"}, {"off", "Off"}, {"line", "One line"}, {"karaoke", "Karaoke fill"}},
  marquee = {{"normal", "Normal"}, {"slow", "Slow"}, {"fast", "Fast"}, {"off", "Off (cut off)"}},
}

local settings_ref = nil
local props_ref    = nil
local hk = {}
local nonce = 0

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
local function log(msg) obs.script_log(obs.LOG_INFO, "[Plexamp Now Playing] " .. msg) end
local function warn(msg) obs.script_log(obs.LOG_WARNING, "[Plexamp Now Playing] " .. msg) end

local function trim(s)
  s = s or ""
  s = s:gsub("^%s+", "")
  s = s:gsub("%s+$", "")
  return s
end

local function file_exists(path)
  local f = io.open(path, "r")
  if f then f:close() return true end
  return false
end

local function theme_by_id(id)
  for _, t in ipairs(THEMES) do if t.id == id then return t end end
  return THEMES[1]
end

local function theme_index(id)
  for i, t in ipairs(THEMES) do if t.id == id then return i end end
  return 1
end

local function has_variant(t, v)
  for _, x in ipairs(t.variants) do if x[1] == v then return true end end
  return false
end

-- "#e5a00d", "E5A00D", "#fff" -> "#e5a00d"; anything else -> ""
local function hex_color(s)
  s = trim(s):gsub("^#", ""):lower()
  if s:match("^%x%x%x$") then s = s:sub(1, 1):rep(2) .. s:sub(2, 2):rep(2) .. s:sub(3, 3):rep(2) end
  if s:match("^%x%x%x%x%x%x$") then return "#" .. s end
  return ""
end

local function normalize_server(s)
  s = trim(s)
  if s == "" then return "" end
  if not s:match("^https?://") then s = "http://" .. s end
  s = s:gsub("/+$", "")
  local hostport = s:match("^https?://([^/]+)$")
  if hostport and not hostport:match(":%d+$") then s = s .. ":32400" end
  return s
end

local function normalize_token(s)
  s = trim(s)
  return s:match("X%-Plex%-Token=([%w%-_]+)") or s
end

-- style code: pnp1.<theme>.<variant>.<base64url json>
local function parse_code(code)
  code = trim(code)
  local th, va = code:match("^pnp1%.([%w%-]+)%.([%w%-]*)%.[%w%-_]*$")
  return th, va
end

local function json_string(s)
  s = tostring(s or "")
  s = s:gsub('[%c"\\]', function(c)
    local map = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
    return map[c] or string.format("\\u%04x", c:byte())
  end)
  return '"' .. s .. '"'
end

local function json_value(v)
  local t = type(v)
  if t == "boolean" then return v and "true" or "false" end
  if t == "number" then
    if v ~= v or v == math.huge or v == -math.huge then return "0" end
    if v == math.floor(v) then return string.format("%d", v) end
    return tostring(v)
  end
  return json_string(v)
end

---------------------------------------------------------------------------
-- settings -> config for the overlay
---------------------------------------------------------------------------
local LOOK_LISTS = { "colors", "font", "textSize", "textCase", "corners", "background", "ambient", "effect", "textFx",
  "enter", "change", "artShape", "artMotion", "progress", "viz", "react", "lyrics", "marquee" }
local SHOW_BOOLS = { "showAlbum", "showYear", "showQuality", "showTimes", "showEq", "showGenre", "showDevice", "showRating", "showPlays" }

local function build_config(s)
  local g, b, i = obs.obs_data_get_string, obs.obs_data_get_bool, obs.obs_data_get_int
  local cfg = {
    { "server", normalize_server(g(s, "server")) },
    { "token", normalize_token(g(s, "token")) },
    { "user", trim(g(s, "user")) },
    { "player", trim(g(s, "player")) },
    { "plexampOnly", b(s, "plexampOnly") },
    { "theme", g(s, "theme") },
    { "variant", g(s, "variant") },
    { "styleCode", trim(g(s, "styleCode")) },
  }
  for _, k in ipairs(LOOK_LISTS) do cfg[#cfg + 1] = { k, g(s, k) } end
  cfg[#cfg + 1] = { "accent", hex_color(g(s, "accent")) }
  cfg[#cfg + 1] = { "bg", hex_color(g(s, "bg")) }
  cfg[#cfg + 1] = { "ink", hex_color(g(s, "ink")) }
  cfg[#cfg + 1] = { "opacity", i(s, "opacity") }
  for _, k in ipairs(SHOW_BOOLS) do cfg[#cfg + 1] = { k, b(s, k) } end
  cfg[#cfg + 1] = { "label", g(s, "label") }
  cfg[#cfg + 1] = { "hidePaused", b(s, "hidePaused") }
  cfg[#cfg + 1] = { "hidePausedDelay", i(s, "hidePausedDelay") }
  cfg[#cfg + 1] = { "peek", b(s, "peek") }
  cfg[#cfg + 1] = { "peekSeconds", i(s, "peekSeconds") }
  cfg[#cfg + 1] = { "idle", g(s, "idle") }
  cfg[#cfg + 1] = { "lyricsOffset", i(s, "lyricsOffset") }
  cfg[#cfg + 1] = { "setupMessages", b(s, "setupMessages") }
  cfg[#cfg + 1] = { "demo", b(s, "demo") }
  cfg[#cfg + 1] = { "renderScale", tonumber(g(s, "renderScale")) or 1 }
  cfg[#cfg + 1] = { "pollMs", 1000 }
  cfg[#cfg + 1] = { "nonce", nonce }
  return cfg
end

local function encode_config(cfg)
  local parts = {}
  for _, kv in ipairs(cfg) do parts[#parts + 1] = json_string(kv[1]) .. ": " .. json_value(kv[2]) end
  return "{\n  " .. table.concat(parts, ",\n  ") .. "\n}\n"
end

local function write_file(path, text)
  local f, err = io.open(path, "wb")
  if not f then warn("Couldn't write " .. path .. ": " .. tostring(err)) return false end
  f:write(text)
  f:close()
  return true
end

local function write_config(s)
  if s == nil then return end
  local json = encode_config(build_config(s))
  write_file(SCRIPT_DIR .. "config.json", json)
  write_file(SCRIPT_DIR .. "config.js", "window.PNP_CONFIG = " .. json:gsub("\n$", "") .. ";\n")
end

-- which theme/variant is actually showing (a style code wins over the panel)
local function active_look(s)
  local th, va = parse_code(obs.obs_data_get_string(s, "styleCode"))
  if not th then th = obs.obs_data_get_string(s, "theme"); va = obs.obs_data_get_string(s, "variant") end
  local t = theme_by_id(th)
  if not has_variant(t, va) then va = t.variants[1] and t.variants[1][1] or "" end
  return t, va
end

local function source_size(s)
  local t, va = active_look(s)
  local dims = (t.sizes and t.sizes[va]) or t.size
  local scale = tonumber(obs.obs_data_get_string(s, "renderScale")) or 1
  return math.floor(dims[1] * scale + 0.5), math.floor(dims[2] * scale + 0.5)
end

---------------------------------------------------------------------------
-- overlay (browser source)
---------------------------------------------------------------------------
local function fill_overlay_settings(s, data)
  local w, h = source_size(s)
  obs.obs_data_set_bool(data, "is_local_file", true)
  obs.obs_data_set_string(data, "local_file", SCRIPT_DIR .. HTML_FILE)
  obs.obs_data_set_int(data, "width", w)
  obs.obs_data_set_int(data, "height", h)
  obs.obs_data_set_bool(data, "shutdown", false)
  obs.obs_data_set_bool(data, "restart_when_active", false)
  obs.obs_data_set_bool(data, "reroute_audio", false)
end

local function update_overlay_source(s)
  local src = obs.obs_get_source_by_name(OVERLAY_NAME)
  if src == nil then return end
  local data = obs.obs_data_create()
  fill_overlay_settings(s, data)
  obs.obs_source_update(src, data)
  obs.obs_data_release(data)
  obs.obs_source_release(src)
end

local function with_current_scene(fn)
  local scene_src = obs.obs_frontend_get_current_scene()
  if scene_src == nil then return end
  local scene = obs.obs_scene_from_source(scene_src)
  if scene ~= nil then fn(scene) end
  obs.obs_source_release(scene_src)
end

local function add_overlay_to_scene()
  if not file_exists(SCRIPT_DIR .. HTML_FILE) then
    warn(HTML_FILE .. " is missing from " .. SCRIPT_DIR .. " - put it next to this script.")
    return
  end
  local src = obs.obs_get_source_by_name(OVERLAY_NAME)
  if src == nil then
    local data = obs.obs_data_create()
    fill_overlay_settings(settings_ref, data)
    src = obs.obs_source_create("browser_source", OVERLAY_NAME, data, nil)
    obs.obs_data_release(data)
  end
  with_current_scene(function(scene)
    if obs.obs_scene_find_source_recursive(scene, OVERLAY_NAME) == nil then
      obs.obs_scene_add(scene, src)
      log("Added the overlay to the current scene.")
    end
  end)
  obs.obs_source_release(src)
end

local function reload_overlay()
  local src = obs.obs_get_source_by_name(OVERLAY_NAME)
  if src == nil then return end
  local props = obs.obs_source_properties(src)
  local btn = obs.obs_properties_get(props, "refreshnocache")
  if btn ~= nil then obs.obs_property_button_clicked(btn, src) end
  obs.obs_properties_destroy(props)
  obs.obs_source_release(src)
end

local function toggle_overlay()
  with_current_scene(function(scene)
    local item = obs.obs_scene_find_source_recursive(scene, OVERLAY_NAME)
    if item ~= nil then obs.obs_sceneitem_set_visible(item, not obs.obs_sceneitem_visible(item)) end
  end)
end

---------------------------------------------------------------------------
-- Style Studio: open it, and receive looks it sends through obs-websocket
---------------------------------------------------------------------------
local ffi_ok, ffi = pcall(require, "ffi")
local IS_WINDOWS = package.config:sub(1, 1) == "\\"
local win = nil   -- Windows helpers: win.run(file, params) -> ok, win.reg(root, key, value) -> string
if ffi_ok and ffi.os == "Windows" then
  pcall(ffi.cdef, [[ int MultiByteToWideChar(unsigned int cp, unsigned long flags, const char* str, int cb, wchar_t* wstr, int cch); ]])
  pcall(ffi.cdef, [[ int WideCharToMultiByte(unsigned int cp, unsigned long flags, const wchar_t* wstr, int cch, char* str, int cb, const char* def, int* used); ]])
  pcall(ffi.cdef, [[ long RegGetValueW(void* hkey, const wchar_t* sub, const wchar_t* value, unsigned long flags, unsigned long* type, void* data, unsigned long* size); ]])
  pcall(ffi.cdef, [[
    typedef struct {
      unsigned long cbSize; unsigned long fMask; void* hwnd;
      const wchar_t* lpVerb; const wchar_t* lpFile; const wchar_t* lpParameters; const wchar_t* lpDirectory;
      int nShow; void* hInstApp; void* lpIDList; const wchar_t* lpClass; void* hkeyClass;
      unsigned long dwHotKey; void* hIconOrMonitor; void* hProcess;
    } PNP_SHELLEXECUTEINFOW;
    int ShellExecuteExW(PNP_SHELLEXECUTEINFOW* info);
  ]])
  local ok1, shell32 = pcall(ffi.load, "shell32")
  local ok2, advapi = pcall(ffi.load, "advapi32")
  if ok1 then
    win = {}
    local function wide(str)
      local n = ffi.C.MultiByteToWideChar(65001, 0, str, -1, nil, 0)
      local buf = ffi.new("wchar_t[?]", n)
      ffi.C.MultiByteToWideChar(65001, 0, str, -1, buf, n)
      return buf
    end
    local function narrow(w)
      local n = ffi.C.WideCharToMultiByte(65001, 0, w, -1, nil, 0, nil, nil)
      if n <= 0 then return nil end
      local buf = ffi.new("char[?]", n)
      ffi.C.WideCharToMultiByte(65001, 0, w, -1, buf, n, nil, nil)
      return ffi.string(buf, n - 1)
    end
    -- ShellExecuteEx with SEE_MASK_FLAG_NO_UI: fails quietly instead of popping up Windows error boxes
    win.run = function(file, params)
      local keep = { wide("open"), wide(file), params and wide(params) or nil }
      local info = ffi.new("PNP_SHELLEXECUTEINFOW")
      info.cbSize = ffi.sizeof(info)
      info.fMask = 0x00000400 + 0x00000100   -- FLAG_NO_UI + NOASYNC
      info.lpVerb, info.lpFile, info.lpParameters, info.nShow = keep[1], keep[2], keep[3], 1
      win._keep = keep   -- keep the strings alive while Windows uses them
      return shell32.ShellExecuteExW(info) ~= 0, tonumber(ffi.cast("intptr_t", info.hInstApp))
    end
    win.HKCU = ffi.cast("void*", ffi.cast("intptr_t", -2147483647))   -- 0x80000001, sign-extended like WinReg.h
    win.HKCR = ffi.cast("void*", ffi.cast("intptr_t", -2147483648))   -- 0x80000000
    if ok2 then
      win.reg = function(root, key, value)
        local size = ffi.new("unsigned long[1]", 0)
        local wk, wv = wide(key), value and wide(value) or nil
        if advapi.RegGetValueW(root, wk, wv, 0x2, nil, nil, size) ~= 0 or size[0] == 0 then return nil end
        local buf = ffi.new("uint8_t[?]", size[0] + 4)
        if advapi.RegGetValueW(root, wk, wv, 0x2, nil, buf, size) ~= 0 then return nil end
        return narrow(ffi.cast("const wchar_t*", buf))
      end
    end
  end
end

-- file:///D:/folder/page.html, safe to hand to any browser's command line
local function file_url(path)
  local u = path:gsub("\\", "/"):gsub("[%% #?\"]", function(c) return string.format("%%%02X", c:byte()) end)
  return "file:///" .. u:gsub("^/+", "")
end

-- Your default web browser's program and the arguments to open url with it (from Windows' https association)
local function default_browser(url)
  if not (win and win.reg) then return nil end
  local base = "Software\\Microsoft\\Windows\\Shell\\Associations\\UrlAssociations\\"
  local progid
  for _, k in ipairs({ "https\\UserChoiceLatest", "https\\UserChoice", "http\\UserChoiceLatest", "http\\UserChoice" }) do
    progid = win.reg(win.HKCU, base .. k, "ProgId")
    if progid and progid ~= "" then break end
  end
  if not progid or progid == "" then return nil end
  local cmd = win.reg(win.HKCR, progid .. "\\shell\\open\\command", nil)
  if not cmd or cmd == "" then return nil end
  cmd = trim(cmd)
  local exe, rest
  if cmd:sub(1, 1) == '"' then exe, rest = cmd:match('^"([^"]+)"%s*(.*)$') else exe, rest = cmd:match("^(%S+)%s*(.*)$") end
  if not exe then return nil end
  local used = false
  rest = rest:gsub("%%[1lL]", function() used = true return url end):gsub("%%%*", "")
  if not used then rest = trim(rest .. " " .. url) end
  return exe, rest, progid
end

local studio_msg = ""    -- shown under the button after a click
local function open_studio()
  local path = SCRIPT_DIR .. STUDIO_FILE
  local shown = IS_WINDOWS and path:gsub("/", "\\") or path
  if not file_exists(path) then
    studio_msg = "Couldn't find " .. STUDIO_FILE .. " in this folder:\n" .. (IS_WINDOWS and SCRIPT_DIR:gsub("/", "\\") or SCRIPT_DIR) ..
      "\nPut it there, next to plexamp-now-playing.lua, then click the button again."
    warn(studio_msg)
    return false
  end
  local url = file_url(path)
  local how
  if win then
    -- 1) your default browser, read from Windows settings (works even when .html files have no app set)
    local exe, args, progid = default_browser(url)
    if exe then
      local ok, code = win.run(exe, args)
      if ok then how = "default browser (" .. progid .. ")" end
      if not ok then log("Default browser " .. tostring(progid) .. " didn't start (" .. tostring(code) .. "): " .. exe) end
    end
    -- 2) whatever app opens .html files
    if not how and win.run(shown, nil) then how = ".html file association" end
    -- 3) any browser Windows knows about
    if not how then
      for _, b in ipairs({ "msedge.exe", "chrome.exe", "firefox.exe", "brave.exe", "opera.exe" }) do
        if win.run(b, url) then how = b break end
      end
    end
  elseif not IS_WINDOWS then
    local p = io.popen("uname")
    local uname = p and p:read("*l") or ""
    if p then p:close() end
    if uname == "Darwin" then os.execute('open "' .. path .. '"') else os.execute('xdg-open "' .. path .. '" >/dev/null 2>&1 &') end
    how = "system opener"
  end
  if how then
    log("Opened the Style Studio with " .. how .. ": " .. shown)
    studio_msg = "Opened the Style Studio in your web browser. If you don't see it, check the taskbar (it can open behind OBS), or paste this into your browser's address bar:\n" .. url
    return true
  end
  warn("Couldn't open the Style Studio automatically: " .. shown)
  studio_msg = "Windows couldn't find a browser to open the Studio with. Open your browser and paste this into the address bar:\n" .. url
  return false
end


local function apply_style_code(code, rev)
  if settings_ref == nil then return end
  obs.obs_data_set_string(settings_ref, "styleCode", code)
  if rev then obs.obs_data_set_string(settings_ref, "bridgeRev", rev) end
  write_config(settings_ref)
  update_overlay_source(settings_ref)
end

---------------------------------------------------------------------------
-- presets: your own named looks, saved in presets.json next to this script
-- (presets.js mirrors it so the Style Studio can show them)
---------------------------------------------------------------------------
local PRESETS_FILE = "presets.json"
local PRESETS_JS   = "presets.js"
local PRESET_SLOTS = 10       -- hotkeys "Plexamp: Preset 1" .. "Preset 10"
local presets = {}            -- { { name = "...", code = "pnp1..." }, ... }
local presets_text = nil      -- what presets.json last contained (to notice edits made elsewhere)
local preset_msg = ""         -- feedback line in the Presets group
local delete_armed = nil      -- { name =, at = } : Delete needs a second click

local STYLE_TYPE = {}
for _, k in ipairs(STYLE_KEYS) do
  local v = STYLE_BUILTIN[k]
  STYLE_TYPE[k] = type(v) == "boolean" and "bool" or (type(v) == "number" and "int" or "string")
end
local HEX_KEYS = { accent = true, bg = true, ink = true }

-- base64url, same flavour the overlay and the Studio use
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local B64INV = {}
for i = 1, 64 do B64INV[B64:sub(i, i)] = i - 1 end
B64INV["+"] = 62; B64INV["/"] = 63
local function b64_encode(str)
  local out = {}
  for i = 1, #str, 3 do
    local a, b, c = str:byte(i, i + 2)
    local n = a * 65536 + (b or 0) * 256 + (c or 0)
    local i1, i2 = math.floor(n / 262144) % 64, math.floor(n / 4096) % 64
    local i3, i4 = math.floor(n / 64) % 64, n % 64
    out[#out + 1] = B64:sub(i1 + 1, i1 + 1) .. B64:sub(i2 + 1, i2 + 1)
    if b then out[#out + 1] = B64:sub(i3 + 1, i3 + 1) end
    if c then out[#out + 1] = B64:sub(i4 + 1, i4 + 1) end
  end
  return table.concat(out)
end
local function b64_decode(str)
  str = str:gsub("[^%w%-_+/]", "")
  local out = {}
  for i = 1, #str, 4 do
    local n, k = 0, 0
    for j = 0, 3 do
      local v = B64INV[str:sub(i + j, i + j)]
      n = n * 64 + (v or 0)
      if v then k = k + 1 end
    end
    if k >= 2 then out[#out + 1] = string.char(math.floor(n / 65536) % 256) end
    if k >= 3 then out[#out + 1] = string.char(math.floor(n / 256) % 256) end
    if k >= 4 then out[#out + 1] = string.char(n % 256) end
  end
  return table.concat(out)
end

local function option_has(key, value)
  for _, it in ipairs(OPTIONS[key] or {}) do if it[1] == value then return true end end
  return false
end

-- what a theme/variant uses for a key when you leave it on "theme default"
local function theme_default(t, variant, key)
  local vd = t.vdefaults and t.vdefaults[variant]
  if vd and vd[key] ~= nil then return vd[key] end
  if t.defaults and t.defaults[key] ~= nil then return t.defaults[key] end
  return STYLE_BUILTIN[key]
end

-- the look set in the Look/Show options, as a style code
local function panel_code(s)
  local t = theme_by_id(obs.obs_data_get_string(s, "theme"))
  local va = obs.obs_data_get_string(s, "variant")
  if not has_variant(t, va) then va = t.variants[1] and t.variants[1][1] or "" end
  local parts = {}
  for _, k in ipairs(STYLE_KEYS) do
    local ty, v = STYLE_TYPE[k], nil
    if ty == "bool" then v = obs.obs_data_get_bool(s, k)
    elseif ty == "int" then v = obs.obs_data_get_int(s, k)
    else
      v = obs.obs_data_get_string(s, k)
      if HEX_KEYS[k] then v = hex_color(v) end
      if k ~= "label" and (v == "" or v == "theme") then v = nil end
    end
    if v ~= nil then parts[#parts + 1] = json_string(k) .. ":" .. json_value(v) end
  end
  return "pnp1." .. t.id .. "." .. va .. "." .. b64_encode("{" .. table.concat(parts, ",") .. "}")
end

-- the look that's showing right now (a style code wins over the panel)
local function current_code(s)
  local code = trim(obs.obs_data_get_string(s, "styleCode"))
  if parse_code(code) then return code end
  return panel_code(s)
end

-- turn a style code back into Look/Show settings so you can tweak it in this panel
local function unpack_code(s, code)
  code = trim(code)
  local th, va = parse_code(code)
  if not th then return false end
  local t = theme_by_id(th)
  if not has_variant(t, va) then va = t.variants[1] and t.variants[1][1] or "" end
  local body = b64_decode(code:match("%.([%w%-_]*)$") or "")
  local d = nil
  if body ~= "" then d = obs.obs_data_create_from_json(body) end
  obs.obs_data_set_string(s, "theme", t.id)
  obs.obs_data_set_string(s, "variant", va)
  for _, k in ipairs(STYLE_KEYS) do
    local ty = STYLE_TYPE[k]
    local has = d ~= nil and obs.obs_data_has_user_value(d, k)
    if ty == "bool" then
      local v = theme_default(t, va, k)
      if has then v = obs.obs_data_get_bool(d, k) end
      obs.obs_data_set_bool(s, k, v and true or false)
    elseif ty == "int" then
      local v = tonumber(theme_default(t, va, k)) or 100
      if has then v = obs.obs_data_get_int(d, k) end
      obs.obs_data_set_int(s, k, v)
    else
      local v
      if has then v = obs.obs_data_get_string(d, k)
      elseif HEX_KEYS[k] or k == "label" then v = ""
      elseif option_has(k, "theme") then v = "theme"
      else v = tostring(theme_default(t, va, k) or "") end
      if not HEX_KEYS[k] and k ~= "label" and OPTIONS[k] and not option_has(k, v) then v = option_has(k, "theme") and "theme" or tostring(STYLE_BUILTIN[k]) end
      obs.obs_data_set_string(s, k, v)
    end
  end
  if d ~= nil then obs.obs_data_release(d) end
  obs.obs_data_set_string(s, "styleCode", "")
  return true
end

local function preset_index(name)
  if not name or name == "" then return nil end
  local low = name:lower()
  for i, p in ipairs(presets) do if p.name:lower() == low then return i end end
  return nil
end

local function preset_index_by_code(code)
  code = trim(code or "")
  if code == "" then return nil end
  for i, p in ipairs(presets) do if p.code == code then return i end end
  return nil
end

local function clean_name(name)
  name = trim(tostring(name or "")):gsub("%c", " "):gsub("%s+", " ")
  if #name > 60 then name = name:sub(1, 60) end
  return trim(name)
end

local function free_name()
  local n = #presets + 1
  while preset_index("Preset " .. n) do n = n + 1 end
  return "Preset " .. n
end

local function write_presets_js()
  local arr = {}
  for _, p in ipairs(presets) do arr[#arr + 1] = "{\"name\":" .. json_string(p.name) .. ",\"code\":" .. json_string(p.code) .. "}" end
  write_file(SCRIPT_DIR .. PRESETS_JS, "window.PNP_PRESETS = [" .. table.concat(arr, ",") .. "];\n")
end

local function write_presets()
  local items = {}
  for _, p in ipairs(presets) do
    items[#items + 1] = "    { \"name\": " .. json_string(p.name) .. ", \"code\": " .. json_string(p.code) .. " }"
  end
  local text = "{\n  \"version\": 1,\n  \"presets\": [\n" .. table.concat(items, ",\n") .. (#items > 0 and "\n" or "") .. "  ]\n}\n"
  if write_file(SCRIPT_DIR .. PRESETS_FILE, text) then presets_text = text end
  write_presets_js()
end

-- (re)load presets.json; returns true when the list changed
local function read_presets(force)
  local f = io.open(SCRIPT_DIR .. PRESETS_FILE, "rb")
  if not f then
    if force then presets = {}; presets_text = nil; write_presets_js() end
    return false
  end
  local text = f:read("*a") or ""
  f:close()
  if not force and text == presets_text then return false end
  presets_text = text
  local d = obs.obs_data_create_from_json(text)
  if d == nil then
    warn(PRESETS_FILE .. " couldn't be read (it isn't valid JSON), so the presets already loaded are kept.")
    return false
  end
  local list, seen = {}, {}
  local arr = obs.obs_data_get_array(d, "presets")
  if arr ~= nil then
    for i = 0, obs.obs_data_array_count(arr) - 1 do
      local it = obs.obs_data_array_item(arr, i)
      local name, code = clean_name(obs.obs_data_get_string(it, "name")), trim(obs.obs_data_get_string(it, "code"))
      if name ~= "" and parse_code(code) and not seen[name:lower()] then
        seen[name:lower()] = true
        list[#list + 1] = { name = name, code = code }
      end
      obs.obs_data_release(it)
    end
    obs.obs_data_array_release(arr)
  end
  obs.obs_data_release(d)
  presets = list
  write_presets_js()
  return true
end

local function apply_preset(i)
  local p = presets[i]
  if p == nil or settings_ref == nil then return false end
  obs.obs_data_set_string(settings_ref, "styleCode", p.code)
  obs.obs_data_set_string(settings_ref, "presetActive", p.name)
  obs.obs_data_set_string(settings_ref, "presetPick", p.name)
  write_config(settings_ref)
  update_overlay_source(settings_ref)
  log("Preset " .. i .. ": " .. p.name)
  return true
end

local function cycle_preset(dir)
  if settings_ref == nil then return end
  if #presets == 0 then log("No presets yet. Save one in Tools -> Scripts -> Plexamp Now Playing -> Presets.") return end
  -- where are we now: the preset you last switched to, unless the look has changed since
  local cur = trim(obs.obs_data_get_string(settings_ref, "styleCode"))
  local i = preset_index(obs.obs_data_get_string(settings_ref, "presetActive"))
  if not (i and presets[i].code == cur) then i = preset_index_by_code(cur) or i end
  if i == nil then i = dir > 0 and 0 or 1 end
  apply_preset(((i - 1 + dir) % #presets) + 1)
end

-- the edits; each returns a message for the panel
local function preset_save(name, code)
  name = clean_name(name)
  if name == "" then name = free_name() end
  if not parse_code(code) then return nil, "That isn't a style code, so nothing was saved." end
  local i = preset_index(name)
  if i then
    presets[i].code = code
    write_presets()
    return i, "Updated \"" .. presets[i].name .. "\" (preset " .. i .. ")."
  end
  presets[#presets + 1] = { name = name, code = code }
  write_presets()
  return #presets, "Saved \"" .. name .. "\" as preset " .. #presets .. "."
end

local function preset_delete(name)
  local i = preset_index(name)
  if not i then return "Pick a preset first." end
  local gone = table.remove(presets, i)
  write_presets()
  if settings_ref then
    if obs.obs_data_get_string(settings_ref, "presetPick"):lower() == gone.name:lower() then obs.obs_data_set_string(settings_ref, "presetPick", "") end
    if obs.obs_data_get_string(settings_ref, "presetActive"):lower() == gone.name:lower() then obs.obs_data_set_string(settings_ref, "presetActive", "") end
  end
  return "Deleted \"" .. gone.name .. "\"."
end

local function preset_rename(name, to)
  local i = preset_index(name)
  if not i then return "Pick a preset first." end
  to = clean_name(to)
  if to == "" then return "Type the new name in the Name box first." end
  local j = preset_index(to)
  if j and j ~= i then return "There's already a preset called \"" .. presets[j].name .. "\"." end
  local old = presets[i].name
  presets[i].name = to
  write_presets()
  if settings_ref then
    if obs.obs_data_get_string(settings_ref, "presetPick"):lower() == old:lower() then obs.obs_data_set_string(settings_ref, "presetPick", to) end
    if obs.obs_data_get_string(settings_ref, "presetActive"):lower() == old:lower() then obs.obs_data_set_string(settings_ref, "presetActive", to) end
  end
  return "Renamed \"" .. old .. "\" to \"" .. to .. "\"."
end

local function preset_move(name, to_index)
  local i = preset_index(name)
  if not i then return "Pick a preset first." end
  to_index = math.max(1, math.min(#presets, math.floor(tonumber(to_index) or i)))
  if to_index == i then return "\"" .. presets[i].name .. "\" is preset " .. i .. "." end
  local p = table.remove(presets, i)
  table.insert(presets, to_index, p)
  write_presets()
  return "\"" .. p.name .. "\" is now preset " .. to_index .. "."
end

-- the Studio sends edits as JSON in "pnp_preset_op" on the overlay's browser source
local function preset_op(json)
  local d = obs.obs_data_create_from_json(json or "")
  if d == nil then return end
  local g = function(k) return obs.obs_data_get_string(d, k) end
  local op, name, msg = g("op"), g("name"), nil
  if op == "save" then
    local i
    i, msg = preset_save(name, g("code"))
    if i and obs.obs_data_get_bool(d, "use") then apply_preset(i) end
  elseif op == "delete" then msg = preset_delete(name)
  elseif op == "rename" then msg = preset_rename(name, g("to"))
  elseif op == "move" then msg = preset_move(name, obs.obs_data_get_int(d, "index"))
  elseif op == "use" then
    local i = preset_index(name)
    if i then apply_preset(i); msg = "Switched to \"" .. presets[i].name .. "\"." end
  end
  obs.obs_data_release(d)
  if msg then preset_msg = msg; log("Style Studio: " .. msg) end
end

-- The Studio stores its look on the overlay's browser source as "pnp_style" + "pnp_style_rev".
-- (Extra settings don't reload the page.) We pick that up here and save it as the style code.
local poll_count = 0
local function bridge_poll()
  if settings_ref == nil then return end
  poll_count = poll_count + 1
  if poll_count % 4 == 0 then read_presets(false) end   -- presets.json edited or copied in by hand
  local sources = obs.obs_enum_sources()
  if sources == nil then return end
  local best_rev, best_code, op_rev, op_json = nil, nil, nil, nil
  for _, src in ipairs(sources) do
    local id = obs.obs_source_get_unversioned_id(src)
    if id == "browser_source" then
      local s = obs.obs_source_get_settings(src)
      local lf = obs.obs_data_get_string(s, "local_file")
      if lf:sub(-#HTML_FILE) == HTML_FILE then
        local rev = obs.obs_data_get_string(s, "pnp_style_rev")
        if rev ~= "" and (best_rev == nil or rev > best_rev) then
          best_rev = rev
          best_code = obs.obs_data_get_string(s, "pnp_style")
        end
        local prev = obs.obs_data_get_string(s, "pnp_preset_rev")
        if prev ~= "" and (op_rev == nil or prev > op_rev) then
          op_rev = prev
          op_json = obs.obs_data_get_string(s, "pnp_preset_op")
        end
      end
      obs.obs_data_release(s)
    end
  end
  obs.source_list_release(sources)
  if best_rev and best_rev ~= obs.obs_data_get_string(settings_ref, "bridgeRev") then
    apply_style_code(best_code or "", best_rev)
    -- keep the Presets list honest: show the preset this look is, or none
    local i = preset_index_by_code(best_code)
    if i then obs.obs_data_set_string(settings_ref, "presetActive", presets[i].name) end
    obs.obs_data_set_string(settings_ref, "presetPick", i and presets[i].name or "")
    log("Got a new look from the Style Studio.")
  end
  if op_rev and op_rev ~= obs.obs_data_get_string(settings_ref, "presetRev") then
    obs.obs_data_set_string(settings_ref, "presetRev", op_rev)
    preset_op(op_json)
  end
end

---------------------------------------------------------------------------
-- theme hotkeys
---------------------------------------------------------------------------
local function cycle_theme(dir)
  if settings_ref == nil then return end
  local code = trim(obs.obs_data_get_string(settings_ref, "styleCode"))
  local cur = active_look(settings_ref)
  local n = #THEMES
  local nxt = THEMES[((theme_index(cur.id) - 1 + dir) % n) + 1]
  local th = parse_code(code)
  if th then
    local body = code:match("^pnp1%.[%w%-]+%.[%w%-]*%.([%w%-_]*)$") or ""
    obs.obs_data_set_string(settings_ref, "styleCode", "pnp1." .. nxt.id .. ".." .. body)
  else
    obs.obs_data_set_string(settings_ref, "theme", nxt.id)
    obs.obs_data_set_string(settings_ref, "variant", nxt.variants[1] and nxt.variants[1][1] or "")
  end
  write_config(settings_ref)
  update_overlay_source(settings_ref)
  log("Theme: " .. nxt.name)
end

---------------------------------------------------------------------------
-- Plexamp visualizer (window capture)
---------------------------------------------------------------------------
local BLEND = {
  screen   = function() return obs.OBS_BLEND_SCREEN end,
  additive = function() return obs.OBS_BLEND_ADDITIVE end,
  lighten  = function() return obs.OBS_BLEND_LIGHTEN end,
  normal   = function() return obs.OBS_BLEND_NORMAL end,
}

local function get_vis_source()
  local src = obs.obs_get_source_by_name(VIS_NAME)
  if src ~= nil then return src end
  local data = obs.obs_data_create()
  obs.obs_data_set_string(data, "window", "Plexamp:Chrome_WidgetWin_1:Plexamp.exe")
  obs.obs_data_set_int(data, "priority", 2)
  obs.obs_data_set_int(data, "method", 2)
  obs.obs_data_set_bool(data, "cursor", false)
  obs.obs_data_set_bool(data, "client_area", true)
  src = obs.obs_source_create("window_capture", VIS_NAME, data, nil)
  obs.obs_data_release(data)
  log("Created the Plexamp window capture.")
  return src
end

local function apply_vis_style(item)
  if item == nil or settings_ref == nil then return end
  local blend = BLEND[obs.obs_data_get_string(settings_ref, "visBlend")] or BLEND.screen
  obs.obs_sceneitem_set_blending_mode(item, blend())
  local fade = obs.obs_data_get_bool(settings_ref, "visFade")
  local ms = obs.obs_data_get_int(settings_ref, "visFadeMs")
  local ok, err = pcall(function()
    for _, show in ipairs({ true, false }) do
      if fade then
        local tr = obs.obs_source_create_private("fade_transition", "Plexamp visualizer fade", nil)
        obs.obs_sceneitem_set_transition(item, show, tr)
        obs.obs_sceneitem_set_transition_duration(item, show, ms)
        obs.obs_source_release(tr)
      else
        obs.obs_sceneitem_set_transition(item, show, nil)
      end
    end
  end)
  if not ok then warn("Couldn't set the visualizer fade: " .. tostring(err)) end
end

local function top_item_name(scene)
  local items = obs.obs_scene_enum_items(scene)
  local name = nil
  if items ~= nil and #items > 0 then name = obs.obs_source_get_name(obs.obs_sceneitem_get_source(items[#items])) end
  obs.sceneitem_list_release(items)
  return name
end

local function toggle_visualizer()
  with_current_scene(function(scene)
    local item = obs.obs_scene_find_source_recursive(scene, VIS_NAME)
    if item == nil then
      local overlay_on_top = top_item_name(scene) == OVERLAY_NAME
      local src = get_vis_source()
      item = obs.obs_scene_add(scene, src)
      obs.obs_source_release(src)
      apply_vis_style(item)
      if overlay_on_top then obs.obs_sceneitem_set_order(item, obs.OBS_ORDER_MOVE_DOWN) end
      obs.obs_sceneitem_set_visible(item, true)
      log("Visualizer added to the current scene.")
    else
      obs.obs_sceneitem_set_visible(item, not obs.obs_sceneitem_visible(item))
    end
  end)
end

local function restyle_visualizer()
  with_current_scene(function(scene) apply_vis_style(obs.obs_scene_find_source_recursive(scene, VIS_NAME)) end)
end

---------------------------------------------------------------------------
-- settings UI  (only crash-safe property types)
---------------------------------------------------------------------------
local function add_list(props, name, label, items)
  local p = obs.obs_properties_add_list(props, name, label, obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
  for _, it in ipairs(items) do obs.obs_property_list_add_string(p, it[2], it[1]) end
  return p
end

local function add_info(props, name, text)
  return obs.obs_properties_add_text(props, name, text, obs.OBS_TEXT_INFO)
end

local function fill_variants(p, t)
  obs.obs_property_list_clear(p)
  for _, v in ipairs(t.variants) do obs.obs_property_list_add_string(p, v[2], v[1]) end
end

local function refresh_visibility(props, s)
  if props == nil or s == nil then return true end
  local function vis(name, on)
    local p = obs.obs_properties_get(props, name)
    if p ~= nil then obs.obs_property_set_visible(p, on) end
  end
  local code = trim(obs.obs_data_get_string(s, "styleCode")) ~= ""
  vis("grp_look", not code)
  vis("grp_show", not code)
  vis("code_on", code)
  vis("btn_unpack", code)
  local custom = obs.obs_data_get_string(s, "colors") == "custom"
  vis("accent", custom); vis("bg", custom); vis("ink", custom)
  vis("hidePausedDelay", obs.obs_data_get_bool(s, "hidePaused"))
  vis("peekSeconds", obs.obs_data_get_bool(s, "peek"))
  vis("visFadeMs", obs.obs_data_get_bool(s, "visFade"))
  return true
end

local function on_modified(props, prop, s) return refresh_visibility(props, s) end

local function fill_presets(p)
  obs.obs_property_list_clear(p)
  obs.obs_property_list_add_string(p, #presets == 0 and "(no presets yet)" or "(pick a preset)", "")
  for i, pr in ipairs(presets) do
    obs.obs_property_list_add_string(p, (i <= PRESET_SLOTS and (i .. ".  ") or "     ") .. pr.name, pr.name)
  end
end

-- after a preset button: refresh the list and show what happened
local function presets_changed(props, msg)
  if msg then preset_msg = msg end
  if props ~= nil then
    local pl = obs.obs_properties_get(props, "presetPick")
    if pl ~= nil then fill_presets(pl) end
    local m = obs.obs_properties_get(props, "preset_msg")
    if m ~= nil then
      obs.obs_property_set_description(m, preset_msg ~= "" and preset_msg or " ")
      obs.obs_property_set_visible(m, preset_msg ~= "")
    end
    refresh_visibility(props, settings_ref)
  end
  return true
end

local function picked() return settings_ref and obs.obs_data_get_string(settings_ref, "presetPick") or "" end

local function on_preset_pick(props, prop, s)
  local name = obs.obs_data_get_string(s, "presetPick")
  -- only switch when you actually choose a different preset (this also runs whenever the panel opens)
  if name ~= "" and name:lower() ~= obs.obs_data_get_string(s, "presetActive"):lower() then
    local i = preset_index(name)
    if i and apply_preset(i) then preset_msg = "Switched to \"" .. presets[i].name .. "\"." end
    return presets_changed(props)
  end
  return refresh_visibility(props, s)
end

local function on_theme_modified(props, prop, s)
  local t = theme_by_id(obs.obs_data_get_string(s, "theme"))
  local vp = obs.obs_properties_get(props, "variant")
  if vp ~= nil then fill_variants(vp, t) end
  if not has_variant(t, obs.obs_data_get_string(s, "variant")) then
    obs.obs_data_set_string(s, "variant", t.variants[1] and t.variants[1][1] or "")
  end
  return refresh_visibility(props, s)
end

function script_description()
  local missing = ""
  if not file_exists(SCRIPT_DIR .. HTML_FILE) then
    missing = "<p style='color:#ff7070'><b>" .. HTML_FILE .. " isn't in this script's folder.</b> Put it next to the .lua file, then reload the script.</p>"
  end
  return [[<h3>Plexamp Now Playing</h3>
<p>]] .. #THEMES .. [[ looks for what Plexamp is playing, from a Plex-style card to a cassette, a split-flap board or a neon sign. Switch them below or design one in the Style Studio.</p>
<p><b>First time:</b> fill in your Plex server and token, then click <b>Add overlay to current scene</b>.</p>]] .. missing
end

function script_properties()
  local props = obs.obs_properties_create()
  props_ref = props

  obs.obs_properties_add_button(props, "btn_add", "Add overlay to current scene", function() add_overlay_to_scene() return false end)
  obs.obs_properties_add_button(props, "btn_studio", "Open the Style Studio", function(pp)
    open_studio()
    local m = obs.obs_properties_get(pp or props_ref, "studio_msg")
    if m ~= nil then
      obs.obs_property_set_description(m, studio_msg)
      obs.obs_property_set_visible(m, true)
    end
    return true
  end)
  local sm = add_info(props, "studio_msg", studio_msg ~= "" and studio_msg or " ")
  obs.obs_property_set_visible(sm, studio_msg ~= "")

  -- presets
  local pr = obs.obs_properties_create()
  local pl = obs.obs_properties_add_list(pr, "presetPick", "Preset", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
  fill_presets(pl)
  obs.obs_property_set_modified_callback(pl, on_preset_pick)
  obs.obs_properties_add_button(pr, "btn_p_use", "Switch to the picked preset", function(pp)
    local i = preset_index(picked())
    if not i then return presets_changed(pp, "Pick a preset in the list first.") end
    apply_preset(i)
    return presets_changed(pp, "Switched to \"" .. presets[i].name .. "\".")
  end)
  local pm = add_info(pr, "preset_msg", preset_msg ~= "" and preset_msg or " ")
  obs.obs_property_set_visible(pm, preset_msg ~= "")
  obs.obs_properties_add_text(pr, "presetName", "Name", obs.OBS_TEXT_DEFAULT)
  obs.obs_properties_add_button(pr, "btn_p_save", "Save the current look as a preset (uses the Name above)", function(pp)
    local name = obs.obs_data_get_string(settings_ref, "presetName")
    local i, msg = preset_save(name, current_code(settings_ref))
    if i then
      obs.obs_data_set_string(settings_ref, "presetName", "")
      obs.obs_data_set_string(settings_ref, "presetPick", presets[i].name)
      obs.obs_data_set_string(settings_ref, "presetActive", presets[i].name)
    end
    return presets_changed(pp, msg)
  end)
  obs.obs_properties_add_button(pr, "btn_p_update", "Overwrite the picked preset with the current look", function(pp)
    local i = preset_index(picked())
    if not i then return presets_changed(pp, "Pick the preset to overwrite first.") end
    local _, msg = preset_save(presets[i].name, current_code(settings_ref))
    obs.obs_data_set_string(settings_ref, "presetActive", presets[i].name)
    return presets_changed(pp, msg)
  end)
  obs.obs_properties_add_button(pr, "btn_p_rename", "Rename the picked preset to the Name above", function(pp)
    local msg = preset_rename(picked(), obs.obs_data_get_string(settings_ref, "presetName"))
    if msg:sub(1, 8) == "Renamed " then obs.obs_data_set_string(settings_ref, "presetName", "") end
    return presets_changed(pp, msg)
  end)
  obs.obs_properties_add_button(pr, "btn_p_up", "Move the picked preset up", function(pp)
    local i = preset_index(picked())
    if not i then return presets_changed(pp, "Pick a preset first.") end
    return presets_changed(pp, preset_move(presets[i].name, i - 1))
  end)
  obs.obs_properties_add_button(pr, "btn_p_down", "Move the picked preset down", function(pp)
    local i = preset_index(picked())
    if not i then return presets_changed(pp, "Pick a preset first.") end
    return presets_changed(pp, preset_move(presets[i].name, i + 1))
  end)
  obs.obs_properties_add_button(pr, "btn_p_delete", "Delete the picked preset", function(pp)
    local i = preset_index(picked())
    if not i then return presets_changed(pp, "Pick a preset first.") end
    local now = os.time()
    if delete_armed and delete_armed.name:lower() == presets[i].name:lower() and now - delete_armed.at <= 8 then
      delete_armed = nil
      return presets_changed(pp, preset_delete(presets[i].name))
    end
    delete_armed = { name = presets[i].name, at = now }
    return presets_changed(pp, "Click Delete again to delete \"" .. presets[i].name .. "\".")
  end)
  add_info(pr, "help_presets", "Presets are your own saved looks. Make a look (here or in the Style Studio), type a name and save it. Switch with the list above, or with hotkeys in Settings → Hotkeys: \"Plexamp: Preset 1\" to \"Preset " .. PRESET_SLOTS .. "\", \"Next preset\" and \"Previous preset\". The Style Studio can save presets here too. They're kept in presets.json next to this script.")
  obs.obs_properties_add_group(props, "grp_presets", "Presets", obs.OBS_GROUP_NORMAL, pr)

  -- size & sharpness (not part of a look, so it stays visible when a preset or Studio look is on)
  local sz = obs.obs_properties_create()
  add_list(sz, "renderScale", "Render size", { { "1", "1x (normal)" }, { "1.5", "1.5x" }, { "2", "2x (sharp on 1440p)" }, { "2.5", "2.5x" }, { "3", "3x (sharp on 4K)" } })
  add_info(sz, "help_scale", "Draws the overlay at a higher resolution so it stays crisp when you make it bigger in your scene. After changing this, the overlay gets bigger on the canvas too, so resize it back down to where you want it.")
  obs.obs_properties_add_group(props, "grp_size", "Size & sharpness", obs.OBS_GROUP_NORMAL, sz)

  -- connection
  local c = obs.obs_properties_create()
  obs.obs_properties_add_text(c, "server", "Plex server address", obs.OBS_TEXT_DEFAULT)
  obs.obs_properties_add_text(c, "token", "Plex token", obs.OBS_TEXT_DEFAULT)
  add_info(c, "help_token", "Address: your server's IP and port, like 192.168.1.20:32400.\nToken: in Plex Web, open any item → ⋯ → Get Info → View XML. Copy everything after X-Plex-Token= in the address bar. Treat it like a password, and don't show this window on stream.")
  obs.obs_properties_add_text(c, "user", "Plex account to follow (blank = server owner, * = anyone)", obs.OBS_TEXT_DEFAULT)
  obs.obs_properties_add_text(c, "player", "Only this device (optional, e.g. your PC's name)", obs.OBS_TEXT_DEFAULT)
  obs.obs_properties_add_bool(c, "plexampOnly", "Only Plexamp (ignore other Plex players)")
  obs.obs_properties_add_button(c, "btn_status", "Show connection status on the overlay", function()
    nonce = nonce + 1
    write_config(settings_ref)
    return false
  end)
  obs.obs_properties_add_group(props, "grp_conn", "Plex connection", obs.OBS_GROUP_NORMAL, c)

  -- look
  local l = obs.obs_properties_create()
  local tl = obs.obs_properties_add_list(l, "theme", "Theme", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
  for _, t in ipairs(THEMES) do obs.obs_property_list_add_string(tl, t.name .. "   (" .. t.group .. ")", t.id) end
  obs.obs_property_set_modified_callback(tl, on_theme_modified)
  local vl = obs.obs_properties_add_list(l, "variant", "Style", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
  if settings_ref then fill_variants(vl, theme_by_id(obs.obs_data_get_string(settings_ref, "theme"))) end
  local cl = add_list(l, "colors", "Colors", OPTIONS.colors)
  obs.obs_property_set_modified_callback(cl, on_modified)
  obs.obs_properties_add_text(l, "accent", "Accent color (hex, like #e5a00d)", obs.OBS_TEXT_DEFAULT)
  obs.obs_properties_add_text(l, "bg", "Background color (hex, like #1b1b2a)", obs.OBS_TEXT_DEFAULT)
  obs.obs_properties_add_text(l, "ink", "Text color (hex, like #ffffff)", obs.OBS_TEXT_DEFAULT)
  add_list(l, "font", "Font", OPTIONS.font)
  add_list(l, "textSize", "Text size", OPTIONS.textSize)
  add_list(l, "textCase", "Letter case", OPTIONS.textCase)
  add_list(l, "corners", "Corners", OPTIONS.corners)
  obs.obs_properties_add_int_slider(l, "opacity", "Opacity (%)", 10, 100, 1)
  add_list(l, "background", "Card background", OPTIONS.background)
  add_list(l, "ambient", "Moving background", OPTIONS.ambient)
  add_list(l, "effect", "Effect", OPTIONS.effect)
  add_list(l, "artShape", "Album cover", OPTIONS.artShape)
  add_list(l, "artMotion", "Cover motion", OPTIONS.artMotion)
  add_list(l, "progress", "Progress", OPTIONS.progress)
  add_list(l, "viz", "Visualizer bars", OPTIONS.viz)
  add_list(l, "react", "React to the music", OPTIONS.react)
  add_list(l, "lyrics", "Lyrics line", OPTIONS.lyrics)
  add_list(l, "enter", "Show / hide animation", OPTIONS.enter)
  add_list(l, "change", "Song change animation", OPTIONS.change)
  add_list(l, "textFx", "Text effect on song change", OPTIONS.textFx)
  add_list(l, "marquee", "Long titles scroll", OPTIONS.marquee)
  add_info(l, "help_react", "Visualizer bars and \"react to the music\" follow the song's loudness from Plex's audio analysis (turn on loudness analysis for your music library). Lyrics come from your Plex server too: LyricFind lyrics with Plex Pass, or .lrc files next to your music.")
  obs.obs_properties_add_group(props, "grp_look", "Look", obs.OBS_GROUP_NORMAL, l)

  -- what to show
  local w = obs.obs_properties_create()
  obs.obs_properties_add_bool(w, "showAlbum", "Album name")
  obs.obs_properties_add_bool(w, "showYear", "Year")
  obs.obs_properties_add_bool(w, "showQuality", "Audio quality (FLAC 24/96, MP3 320…)")
  obs.obs_properties_add_bool(w, "showTimes", "Elapsed / total time")
  obs.obs_properties_add_bool(w, "showEq", "Playing indicator")
  obs.obs_properties_add_bool(w, "showGenre", "Genre")
  obs.obs_properties_add_bool(w, "showRating", "Your star rating")
  obs.obs_properties_add_bool(w, "showPlays", "Play count")
  obs.obs_properties_add_bool(w, "showDevice", "Which device is playing")
  obs.obs_properties_add_text(w, "label", "Small label (optional, e.g. Now playing)", obs.OBS_TEXT_DEFAULT)
  obs.obs_properties_add_group(props, "grp_show", "Show", obs.OBS_GROUP_NORMAL, w)

  -- style studio
  local st = obs.obs_properties_create()
  add_info(st, "code_on", "A Style Studio look is active, so the Look and Show options are hidden. Clear the style code to use them again.")
  obs.obs_properties_add_text(st, "styleCode", "Style code", obs.OBS_TEXT_DEFAULT)
  obs.obs_properties_add_button(st, "btn_clear", "Clear style code", function()
    obs.obs_data_set_string(settings_ref, "styleCode", "")
    write_config(settings_ref); update_overlay_source(settings_ref)
    refresh_visibility(props_ref, settings_ref)
    return true
  end)
  obs.obs_properties_add_button(st, "btn_unpack", "Edit this look in the Look and Show options", function(pp)
    local code = trim(obs.obs_data_get_string(settings_ref, "styleCode"))
    if not unpack_code(settings_ref, code) then return false end
    write_config(settings_ref); update_overlay_source(settings_ref)
    local vp = obs.obs_properties_get(pp or props_ref, "variant")
    if vp ~= nil then fill_variants(vp, theme_by_id(obs.obs_data_get_string(settings_ref, "theme"))) end
    refresh_visibility(pp or props_ref, settings_ref)
    return true
  end)
  add_info(st, "help_studio", "The Style Studio shows every theme live and lets you fine-tune everything. Send the look to OBS from the Studio (needs Tools → WebSocket Server Settings turned on), or copy its style code and paste it here.")
  obs.obs_properties_add_group(props, "grp_studio", "Style Studio", obs.OBS_GROUP_NORMAL, st)
  local sc = obs.obs_properties_get(st, "styleCode")
  if sc ~= nil then obs.obs_property_set_modified_callback(sc, on_modified) end

  -- behavior
  local h = obs.obs_properties_create()
  local hp = obs.obs_properties_add_bool(h, "hidePaused", "Hide when paused")
  obs.obs_property_set_modified_callback(hp, on_modified)
  obs.obs_properties_add_int_slider(h, "hidePausedDelay", "…after (seconds)", 0, 120, 1)
  local pk = obs.obs_properties_add_bool(h, "peek", "Only pop up on song change")
  obs.obs_property_set_modified_callback(pk, on_modified)
  obs.obs_properties_add_int_slider(h, "peekSeconds", "…stay up for (seconds)", 3, 120, 1)
  add_list(h, "idle", "When Plexamp stops", { { "hide", "Hide the overlay" }, { "last", "Keep showing the last song" } })
  obs.obs_properties_add_int_slider(h, "lyricsOffset", "Lyrics timing nudge (ms)", -3000, 3000, 100)
  obs.obs_properties_add_bool(h, "setupMessages", "Show setup messages (turn off once it works)")
  obs.obs_properties_add_bool(h, "demo", "Test card (fake songs for styling)")
  obs.obs_properties_add_group(props, "grp_behavior", "Behavior", obs.OBS_GROUP_NORMAL, h)

  -- Plexamp's own visualizer
  local v = obs.obs_properties_create()
  obs.obs_properties_add_button(v, "btn_vis", "Turn Plexamp visualizer on / off", function() toggle_visualizer() return false end)
  add_list(v, "visBlend", "Blend", { { "screen", "Screen (drops dark background)" }, { "additive", "Additive (brighter)" }, { "lighten", "Lighten" }, { "normal", "Normal (keep background)" } })
  local vf = obs.obs_properties_add_bool(v, "visFade", "Fade in and out")
  obs.obs_property_set_modified_callback(vf, on_modified)
  obs.obs_properties_add_int_slider(v, "visFadeMs", "Fade length (ms)", 100, 3000, 50)
  add_info(v, "help_vis", "Open Plexamp and switch on its visualizer first. The first click adds a capture of the Plexamp window to the current scene; crop it by holding Alt and dragging its edges. Don't minimize Plexamp — it can sit behind other windows.")
  obs.obs_properties_add_group(props, "grp_vis", "Plexamp's visualizer", obs.OBS_GROUP_NORMAL, v)

  obs.obs_properties_add_button(props, "btn_reload", "Reload overlay", function() reload_overlay() return false end)

  refresh_visibility(props, settings_ref)
  return props
end

function script_defaults(s)
  local d = obs.obs_data_set_default_string
  local db = obs.obs_data_set_default_bool
  local di = obs.obs_data_set_default_int
  d(s, "server", ""); d(s, "token", ""); d(s, "user", ""); d(s, "player", ""); db(s, "plexampOnly", true)
  d(s, "theme", "ultrablur"); d(s, "variant", "card"); d(s, "styleCode", ""); d(s, "bridgeRev", "")
  for _, k in ipairs(LOOK_LISTS) do d(s, k, "theme") end
  d(s, "textSize", "m"); d(s, "react", "subtle"); d(s, "marquee", "normal")
  d(s, "accent", ""); d(s, "bg", ""); d(s, "ink", "")
  di(s, "opacity", 100)
  for _, k in ipairs(SHOW_BOOLS) do db(s, k, true) end
  db(s, "showGenre", false); db(s, "showDevice", false); db(s, "showRating", false); db(s, "showPlays", false)
  d(s, "label", "")
  db(s, "hidePaused", true); di(s, "hidePausedDelay", 8)
  db(s, "peek", false); di(s, "peekSeconds", 12)
  d(s, "idle", "hide"); di(s, "lyricsOffset", 0)
  db(s, "setupMessages", true); db(s, "demo", false)
  d(s, "renderScale", "1")
  d(s, "visBlend", "screen"); db(s, "visFade", true); di(s, "visFadeMs", 600)
  d(s, "presetPick", ""); d(s, "presetActive", ""); d(s, "presetName", ""); d(s, "presetRev", "")
end

-- carry settings over from the first version of this script
local function migrate(s)
  local has = function(k) return obs.obs_data_has_user_value(s, k) end
  local g = obs.obs_data_get_string
  if has("layout") and not has("theme") then
    local map = { card = "ultrablur", stack = "ultrablur", bar = "slim", vinyl = "vinyl" }
    local layout = g(s, "layout")
    obs.obs_data_set_string(s, "theme", map[layout] or "ultrablur")
    obs.obs_data_set_string(s, "variant", layout == "stack" and "tall" or (layout == "bar" and "album" or (layout == "vinyl" and "black" or "card")))
  end
  if has("background") and g(s, "background") == "ultrablur" then obs.obs_data_set_string(s, "background", "theme") end
  if has("showProgress") and not obs.obs_data_get_bool(s, "showProgress") and not has("progress") then obs.obs_data_set_string(s, "progress", "none") end
  if has("accentMode") then
    if g(s, "accentMode") == "custom" then obs.obs_data_set_string(s, "colors", "custom") end
    if has("accentHex") then obs.obs_data_set_string(s, "accent", g(s, "accentHex")) end
  end
  if has("solidHex") and not has("bg") then obs.obs_data_set_string(s, "bg", g(s, "solidHex")) end
  if has("textHex") and not has("ink") then obs.obs_data_set_string(s, "ink", g(s, "textHex")) end
  if has("font") and g(s, "font") == "Sora" then obs.obs_data_set_string(s, "font", "theme") end
  if has("animation") and not has("change") then obs.obs_data_set_string(s, "change", g(s, "animation")) end
  if has("slideFrom") and not has("enter") then
    local em = { left = "slide-left", right = "slide-right", top = "slide-down", bottom = "slide-up", none = "fade" }
    obs.obs_data_set_string(s, "enter", em[g(s, "slideFrom")] or "theme")
  end
  for _, k in ipairs({ "layout", "accentMode", "accentHex", "solidHex", "textHex", "animation", "slideFrom", "radius", "solidColor", "textColor", "showProgress" }) do
    if has(k) then obs.obs_data_erase(s, k) end
  end
end

function script_update(s)
  settings_ref = s
  write_config(s)
  update_overlay_source(s)
  restyle_visualizer()
end

local function load_hotkey(s, id, key)
  local arr = obs.obs_data_get_array(s, key)
  obs.obs_hotkey_load(id, arr)
  obs.obs_data_array_release(arr)
end

local function save_hotkey(s, id, key)
  local arr = obs.obs_hotkey_save(id)
  obs.obs_data_set_array(s, key, arr)
  obs.obs_data_array_release(arr)
end

local HOTKEYS = {
  { "plexamp_np_toggle_visualizer", "Plexamp: Toggle visualizer", "hk_toggle_visualizer", function() toggle_visualizer() end },
  { "plexamp_np_toggle_overlay", "Plexamp: Show/hide now playing", "hk_toggle_overlay", function() toggle_overlay() end },
  { "plexamp_np_next_theme", "Plexamp: Next theme", "hk_next_theme", function() cycle_theme(1) end },
  { "plexamp_np_prev_theme", "Plexamp: Previous theme", "hk_prev_theme", function() cycle_theme(-1) end },
  { "plexamp_np_next_preset", "Plexamp: Next preset", "hk_next_preset", function() cycle_preset(1) end },
  { "plexamp_np_prev_preset", "Plexamp: Previous preset", "hk_prev_preset", function() cycle_preset(-1) end },
}
for i = 1, PRESET_SLOTS do
  HOTKEYS[#HOTKEYS + 1] = { "plexamp_np_preset_" .. i, "Plexamp: Preset " .. i, "hk_preset_" .. i, function()
    if presets[i] then apply_preset(i) else log("There's no preset " .. i .. " yet.") end
  end }
end

function script_load(s)
  settings_ref = s
  migrate(s)
  for _, h in ipairs(HOTKEYS) do
    local fn = h[4]
    hk[h[1]] = obs.obs_hotkey_register_frontend(h[1], h[2], function(pressed) if pressed then fn() end end)
    load_hotkey(s, hk[h[1]], h[3])
  end
  read_presets(true)
  write_config(s)
  obs.timer_add(bridge_poll, 700)
  if not file_exists(SCRIPT_DIR .. HTML_FILE) then warn(HTML_FILE .. " not found in " .. SCRIPT_DIR) end
end

function script_unload()
  obs.timer_remove(bridge_poll)
end

function script_save(s)
  for _, h in ipairs(HOTKEYS) do save_hotkey(s, hk[h[1]], h[3]) end
end
