local M = {}

local direct_lower = {
    a = "ä",
    o = "ö",
    u = "ü",
    s = "ß",
    e = "é",
    c = "ç",
}

local direct_upper = {
    a = "Ä",
    o = "Ö",
    u = "Ü",
    s = "ẞ",
    e = "É",
    c = "Ç",
}

local accent_lower = {
    grave = { a = "à", e = "è", u = "ù" },
    asciicircum = { a = "â", e = "ê", i = "î", o = "ô", u = "û" },
    quotedbl = { e = "ë", i = "ï", y = "ÿ" },
    ampersand = { a = "æ", o = "œ" },
}

local accent_upper = {
    grave = { a = "À", e = "È", u = "Ù" },
    asciicircum = { a = "Â", e = "Ê", i = "Î", o = "Ô", u = "Û" },
    quotedbl = { e = "Ë", i = "Ï", y = "Ÿ" },
    ampersand = { a = "Æ", o = "Œ" },
}

local modifiers = {
    Shift_L = true,
    Shift_R = true,
    Control_L = true,
    Control_R = true,
    Alt_L = true,
    Alt_R = true,
    Super_L = true,
    Super_R = true,
    Caps_Lock = true,
}

local function reset(env)
    env.german_mode = false
    env.accent = nil
end

local function key_name(key)
    return (key:repr() or ""):gsub("^Release%+", ""):gsub("^Control%+", ""):gsub("^Alt%+", ""):gsub("^Super%+", ""):gsub("^Shift%+", "")
end

local function letter_of(key)
    local code = key.keycode
    if (code >= 65 and code <= 90) or (code >= 97 and code <= 122) then
        return string.lower(string.char(code))
    end
    local name = key_name(key)
    if #name == 1 then
        local byte = string.byte(name)
        if (byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122) then
            return string.lower(name)
        end
    end
    return nil
end

-- 小狼毫里 Shift+o 有时 keycode 已是大写 O，但 shift() 为 false。
local function wants_upper(key)
    if key:shift() or key:caps() then
        return true
    end
    local code = key.keycode
    if code >= 65 and code <= 90 then
        return true
    end
    local repr = key:repr() or ""
    return repr:find("Shift+", 1, true) ~= nil
end

local function is_modifier(key)
    local repr = key:repr() or ""
    if modifiers[repr] then
        return true
    end
    local code = key.keycode
    return code >= 0xffe1 and code <= 0xffee
end

-- 重音直接用键，不按 Shift：` 抑音符，6 扬抑符，' 分音符，7 连字。
-- 下一个字母再按 Shift 才是大写。
local function accent_of(key)
    if key:shift() or key:ctrl() or key:alt() then
        return nil
    end

    local name = key_name(key)
    local code = key.keycode

    if name == "grave" or name == "`" or code == string.byte("`") then
        return "grave"
    end
    if name == "6" or code == string.byte("6") then
        return "asciicircum"
    end
    if name == "apostrophe" or name == "'" or code == string.byte("'") then
        return "quotedbl"
    end
    if name == "7" or code == string.byte("7") then
        return "ampersand"
    end
    return nil
end

local function commit_mapped(env, key, lower_map, upper_map)
    local ch = letter_of(key)
    if not ch or not lower_map[ch] then
        return false
    end
    local text = wants_upper(key) and upper_map[ch] or lower_map[ch]
    env.engine:commit_text(text)
    reset(env)
    return true
end

function M.init(env)
    reset(env)
end

function M.func(key, env)
    local context = env.engine.context

    if not context:get_option("ascii_mode") then
        reset(env)
        return 2
    end

    if not key:release() and key:repr() == "Control+semicolon" then
        env.german_mode = true
        env.accent = nil
        return 1
    end

    if not env.german_mode then
        return 2
    end

    if key:release() then
        return 2
    end

    if is_modifier(key) then
        return 2
    end

    local accent = accent_of(key)
    if accent then
        env.accent = accent
        return 1
    end

    if env.accent then
        local lower_map = accent_lower[env.accent]
        local upper_map = accent_upper[env.accent]
        if commit_mapped(env, key, lower_map, upper_map) then
            return 1
        end
        reset(env)
        return 2
    end

    if commit_mapped(env, key, direct_lower, direct_upper) then
        return 1
    end

    reset(env)
    return 2
end

return M
