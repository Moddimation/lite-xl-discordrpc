-- mod-version:3 lite-xl 2.1
local core = require "core"
local config = require "core.config"
local common = require "core.common"
local command = require "core.command"
local RootView = require "core.rootview"
local View = require "core.view"
local Object = require "core.object"
local discord = require "plugins.discord-presence.discord"

-- stolen from https://github.com/TorchedSammy/litepresence/ Copyright (c) 2021 TorchedSammy
local function makeTbl(tbl)
	local t = {}
	for exts, ftype in pairs(tbl) do
		for ext in exts:gmatch('[^,]+') do
			t[ext] = ftype
		end
	end
	return t
end

-- extensions mapped to language names
local extTbl = makeTbl {
    ['asm'] = 'assembly',
    ['c,h'] = 'c',
    ['cpp,hpp'] = 'cpp',
    ['cr'] = 'crystal',
    ['cs'] = 'cs',
    ['css'] = 'css',
    ['dart'] = 'dart',
    ['ejs,tmpl'] = 'ejs',
    ['ex,exs'] = 'elixir',
    ['gitignore,gitattributes,gitmodules'] = 'git',
    ['go'] = 'go',
    ['hs'] = 'haskell',
    ['htm,html,mhtml'] = 'html',
    ['png,jpg,jpeg,jfif,gif,webp'] = 'image',
    ['java,class,properties'] = 'java',
    ['js'] = 'javascript',
    ['json'] = 'json',
    ['kt'] = 'kotlin',
    ['lua'] = 'lua',
    ['md,markdown'] = 'markdown',
    ['t'] = 'perl',
    ['php'] = 'php',
    ['py,pyx'] = 'python',
    ['jsx,tsx'] = 'react',
    ['rb'] = 'ruby',
    ['rs'] = 'rust',
    ['sh,bat'] = 'shell',
    ['swift'] = 'swift',
    ['txt,rst,rest'] = 'text',
    ['toml'] = 'toml',
    ['ts'] = 'typescript',
    ['vue'] = 'vue',
    ['xml,svg,yml,yaml,cfg,ini'] = 'xml',
}

-- thanks sammyette

-- some rules for placeholders:
-- %f - filename
-- %F - file path (absolute)
-- %d - file dir
-- %D - file dir (absolute)
-- %w - workspace name
-- %W - workspace path
-- %.n where n is a number - nth function after the string
-- %% DOES NOT NEED TO BE ESCAPED.
config.plugins.discord_rpc = common.merge({
  enabled = true,
  app_id = "749282810971291659",
  edit_text = "Editing %f",
  idle_text = "Idling in %f",
  lower_edit_text = "in %w",
  lower_idle_text = "Idling in %w",
  edit_show_line_num = true,
  idle_show_line_num = true,
  show_elapsed_time = true,
  idle_timeout = 30,
  idle_show_logo = true,
  reconnect = 5,
  config_spec = {
    name = "Discord RPC",
    {
      label = "Enabled",
      description = "Activate the rpc by default.",
      path = "enabled",
      type = "toggle",
      default = config.plugins.discord_rpc.enabled
    },
    {
      label = "Application ID",
      description = "TODO",
      path = "app_id",
      type = "string",
      default = config.plugins.discord_rpc.app_id,
    },
    {
      label = "Idle Details",
      description = "TODO",
      path = "idle_text",
      type = "string",
      default = config.plugins.discord_rpc.idle_text,
    },
    {
      label = "Edit Details",
      description = "TODO",
      path = "lower_edit_text",
      type = "string",
      default = config.plugins.discord_rpc.lower_edit_text,
    },
    {
      label = "Lower Edit Details",
      description = "TODO",
      path = "lower_edit_text",
      type = "string",
      default = config.plugins.discord_rpc.lower_edit_text,
    },
    {
      label = "Lower Idle Details",
      description = "TODO",
      path = "lower_idle_text",
      type = "string",
      default = config.plugins.discord_rpc.lower_idle_text,
    },
    {
      label = "Show Elapsed Time",
      description = "TODO",
      path = "show_elapsed_time",
      type = "toggle",
      default = config.plugins.discord_rpc.show_elapsed_time,
    },
    {
      label = "Show Line Number on Edit",
      description = "TODO",
      path = "show_line_num",
      type = "toggle",
      default = config.plugins.discord_rpc.edit_show_line_num,
    },
    {
      label = "Show Line Number on Idle",
      description = "TODO",
      path = "show_line_num",
      type = "toggle",
      default = config.plugins.discord_rpc.idle_show_line_num,
    },
    {
      label = "Idle Timeout",
      description = "TODO",
      path = "idle_timeout",
      type = "number",
      default = config.plugins.discord_rpc.idle_timeout,
    },
    {
      label = "Reconnect",
      description = "TODO",
      path = "reconnect",
      type = "toggle",
      default = config.plugins.discord_rpc.reconnect,
    },
    {
      label = "Show Logo on Idle",
      description = "TODO",
      path = "idle_show_logo",
      type = "toggle",
      default = config.plugins.discord_rpc.idle_show_logo,
    }
  }
}, config.plugins.discord_rpc)

local function replace_placeholders(data, placeholders)
    local text = type(data) == "string" and data or data[1]
    return string.gsub(text, "%%()(.)(%d*)", function(i, t, n)
        if placeholders[t] then
            return placeholders[t]
        elseif t == "." then
            if type(data) ~= "table" then error("no function provided", 0) end
            if not n or not data[tonumber(n) + 1] then
                error(string.format("invalid function index at %d", i), 0)
            end
            return data[tonumber(n) + 1]()
        else
            return "%" .. t
        end
    end)
end

local Discord = Object:extend()
function Discord:new()
    self.running = false
    self.idle = false
    self.error = false
    self.placeholders = {}

    core.add_thread(function()
        while true do
            coroutine.yield(config.project_scan_rate)
            discord.poll()

            local time = system.get_time()
            if self.running then
                if time - self.last_activity >= config.plugins.discord_rpc.idle_timeout then
                    self.idle = true
                    self:update()
                end
            else
                if not self.error
                    and type(config.plugins.discord_rpc.reconnect) == "number"
                    and self.disconnect ~= nil
                    and time - self.disconnect >= config.plugins.discord_rpc.reconnect then
                    self:start()
                end
            end
        end
    end)
end

local function is_in_file()
    if core.active_view.doc and core.active_view.doc.filename then return true else return false end
end

function Discord:update_placeholders()
    self.placeholders["w"] = common.basename(core.project_dir)
    self.placeholders["W"] = core.project_dir

    if is_in_file() then
        local filename = common.basename(core.active_view.doc.filename)
        self.placeholders["f"] = filename
        self.placeholders["F"] = core.active_view.doc.abs_filename

        local file_dir = string.sub(core.active_view.doc.abs_filename, 1, -#filename - 2)
        self.placeholders["d"] = string.sub(file_dir, #core.project_dir + 1, -1) or "."
        self.placeholders["D"] = file_dir

        local line, col = core.active_view.doc:get_selection()
        self.placeholders["p"] = string.format("%d:%d", line, col)
    else
        for _, t in ipairs { "f", "F", "d", "D" } do
            self.placeholders[t] = core.active_view:get_name()
        end
    end
end

function Discord:update()
    if not self.running then return end
    self:update_placeholders()

    -- copy config to local variables
    local details_raw, state_raw, show_line_num
    if self.idle then
        details_raw = config.plugins.discord_rpc.idle_text
        state_raw = config.plugins.discord_rpc.lower_idle_text
        show_line_num = config.plugins.discord_rpc.idle_show_line_num
    else
        details_raw = config.plugins.discord_rpc.edit_text
        state_raw = config.plugins.discord_rpc.lower_edit_text
        show_line_num = config.plugins.discord_rpc.edit_show_line_num
    end
    -- show line number toggle
    if is_in_file() and show_line_num then
        details_raw = details_raw .. ": " .. "%p"
    end

    local new_status = {
        state = replace_placeholders(state_raw, self.placeholders),
        details = replace_placeholders(details_raw, self.placeholders),
        large_image = "litexl",
        start_time = self.start_time
    }

    local filetype = self.placeholders["f"] and self.placeholders["f"]:match('^.+(%..+)$')

    if filetype then
        local img = extTbl[filetype:sub(2)] -- show logo on idle toggle
        if img and (config.plugins.discord_rpc.idle_show_logo or not self.idle) then
            new_status.large_image = img
            new_status.small_image = "litexl"
        end
    end

    discord.update(new_status)
end

function Discord:start()
    if self.running then return end

    self.running = true
    self.disconnect = nil
    self.last_activity = system.get_time()
    self.start_time = config.plugins.discord_rpc.elapsed_time and os.time() or nil

    discord.on_event("ready", function()
        core.log("lite-xl-discord: connected to RPC!")
        self:update()
    end)
    discord.on_event("disconnect", function(n, err)
        self.running = false
        self.disconnect = system.get_time()
        discord.shutdown()
        core.error("lite-xl-discord: lost RPC connection: %d %s", n, err)
    end)

    core.log("lite-xl-discord: Starting RPC")
    discord.init(config.plugins.discord_rpc.app_id)
end

function Discord:stop()
    self.running = false
    discord.shutdown()
    core.log("lite-xl-discord: RPC stopped.")
end

function Discord:bump()
    self.last_activity = system.get_time()
    if self.idle then
        self.idle = false
        self:update()
    end
end


local rpc = Discord()


-- function replacements

-- unless one day they finally decided that autoreloading user module is not a good idea
-- this will be required since user expects their config to automagically update

local on_quit_project = core.on_quit_project
function core.on_quit_project(...)
    rpc:stop()
    on_quit_project(...)
end

local set_active_view = core.set_active_view
function core.set_active_view(view)
    set_active_view(view)
    core.try(rpc.update, rpc)
end

for _, fn in ipairs { "mouse_pressed", "mouse_released", "text_input" } do
    local oldfn = View["on_" .. fn]
    View["on_" .. fn] = function(...)
        rpc:bump()
        return oldfn(...)
    end
end


-- commands
command.add(nil, {
    ["discord-rpc:stop-RPC"] = function()
        rpc:stop()
    end,
    ["discord-rpc:start-RPC"] = function()
        if not config.plugins.discord_rpc.enabled then return end
        rpc:start()
    end
})


if config.plugins.discord_rpc.enabled then
    rpc:start()
end
