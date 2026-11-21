--!strict
--!optimize 2
-- Roblox's globals for a Lune test, so the real modules a test requires through `@game` find them.
-- A test calls `install` once, before it requires any source. Installed: every datatype
-- `@lune/roblox` provides, `Instance` and `Enum`. A required module reads globals from the thread's
-- environment, not from `_G`, so they are set on getfenv(0); the getfenv call turns off some of
-- Luau's optimizations for the run.
-- Lune has no engine: nothing steps, and an Animator there loads no track. A test passes the
-- controller a stand-in Animator (fakeAnimator.fixture).
local Roblox = require("@lune/roblox")

type RobloxEnvironmentModule = {
	-- Installs the globals on the calling thread's environment.
	read install: () -> (),
}

local function install(): ()
	local environment = getfenv(0)
	for name, value in Roblox :: { [string]: unknown } do
		-- The datatypes, `Instance` and `Enum` are the library's PascalCase members; its camelCase
		-- members are Lune's own functions, not Roblox globals.
		if string.match(name, "^%u") then
			environment[name] = value
		end
	end
end

local module: RobloxEnvironmentModule = table.freeze({ install = install })
return module
