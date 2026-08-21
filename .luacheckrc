-- luacheck config for Everything Delves (World of Warcraft addon; Lua 5.1 runtime).
-- Linter is the maintained lunarmodules fork: https://github.com/lunarmodules/luacheck
-- Run from the repo root: luacheck .

std = "lua51"
max_line_length = false
codes = true

-- Don't lint vendored third-party libraries
exclude_files = { "Libs/**/*.lua" }

-- WoW exposes a huge global API and addons intentionally set/override globals, so
-- maintaining a full allowlist isn't worth it. Silence the global-access family and
-- keep the checks that catch real bugs (syntax errors, unused and shadowed locals,
-- unreachable code).
ignore = {
    "111", -- setting non-standard global
    "112", -- mutating non-standard global
    "113", -- accessing undefined global
    "143", -- accessing undefined field of a global
}

-- Locales/ is generated from the EverythingLocales store. A language with no
-- translations yet declares `local L` and uses it nowhere, which is correct, so
-- only the unused family is silenced here - syntax errors still fail.
files["Locales/*.lua"] = {
    ignore = { "21" },
}
