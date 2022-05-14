#!/bin/hilbish
local fs = require 'fs'

local confDir = string.format('%s/%s', hilbish.userDir.config, 'selene')
local preload = string.format('%s/%s', '/tmp/', 'selene-preload.js')
pcall(fs.mkdir, confDir, false)

-- taken from discocss with some modifications
local preloadFile = io.open(preload, 'w')
local jsInject = [[
module.exports = () => {
	const confDir = '%s/';

	const fs = require('fs');
	const fengari = require(`${confDir}/fengari/src/fengari`)

	const lauxlib  = fengari.lauxlib;
	const lualib   = fengari.lualib;

	const L = lauxlib.luaL_newstate();

	lualib.luaL_openlibs(L);
	function loadLua() {
		lauxlib.luaL_dofile(L, `${confDir}/css.lua`);
		lauxlib.luaL_dofile(L, `${confDir}/init.lua`);
	}

	function reload(style) {
		loadLua()
		const css = lauxlib.luaL_tolstring(L, -1)
		const cssStr = Buffer.from(css).toString()

		style.innerHTML = cssStr
	}

	function inject({ document, window }) {
		window.addEventListener("load", () => {
			const style = document.createElement('style');
			reload(style);
			document.head.appendChild(style);

			fs.watch(confDir, {}, () => reload(style));
		});
	}

	inject(require('electron').webFrame.context);
};

module.exports.mw = (mainWindow) => {
	mainWindow.setBackgroundColor('#00000000');
};

module.exports.mo = (options) => {
	options.transparent = true;
	if (process.platform === 'linux') {
		options.frame = true;
	}
};
]]
preloadFile:write(string.format(jsInject, confDir))
preloadFile:close()

local discordDir = string.format('%s/%s', hilbish.userDir.config, 'discordcanary')
local replacements = {}
-- to write to the asar properly and not mess up the files
-- we need our injected code to have the same length as previous
-- a better way of doing this is just unpacking, replacing, and repacking
-- but this is lua
local function replace(src, dest)
	local srcLen = src:len()
	local destLen = dest:len()
	local padCount = srcLen - destLen
	local paddedDest = dest .. (' '):rep(padCount < 0 and 0 or padCount)

	table.insert(replacements, src)
	table.insert(replacements, paddedDest)

	return padCount < 0 and padCount or nil
end

replace('  // App preload script, used to provide a replacement native API now that', string.format('try {require(\'%s\')()} catch (e) {console.error(e);}', preload))
replace('// launch main app window; could be called multiple times for various reasons', ' const dp = require(\'' .. preload .. '\');')
replace('    mainWindowOptions.frame = true;', '}dp.mo(mainWindowOptions);{')
replace('// causing the window to be too small on a larger secondary display', 'dp.mw(mainWindow);')

local discordDataDirs = fs.readdir(discordDir)
local modulesDir
for _, d in ipairs(discordDataDirs) do
	local dir = string.format('%s/%s/modules', discordDir, d)

	local ok = pcall(fs.readdir, dir)
	if ok then
		modulesDir = dir
		break
	end
end

if not modulesDir then
	print 'could not find modules directory'
	os.exit(2)
end

local modulePath = string.format('%s/discord_desktop_core', modulesDir)
local asarPath = string.format('%s/core.asar', modulePath)
print(asarPath)

local asarFileRead = io.open(asarPath, 'rb')
local asarContent = asarFileRead:read '*a'
local asarFile = io.open(asarPath, 'w')

for i, _ in ipairs(replacements) do
	if i % 2 == 1 then
		local left = replacements[i]
		local right = replacements[i + 1]
		asarContent = asarContent:gsub(left, right)
	end
end

asarFile:write(asarContent)
asarFile:close()
