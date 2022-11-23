-- mod-version:3
-- author: jipok
-- doesn't work well with scaling mode == "ui"


local common = require "core.common"
local config = require "core.config"
local style = require "core.style"
local treeview = require "plugins.treeview"
local node = require "core.node"

local nficons = require "plugins.nficons.icons"

-- config
config.plugins.nficons = common.merge({
  use_default_dir_icons = false,
  use_default_chevrons = false,
  draw_treeview_icons = true,
  draw_tab_icons = true,
  -- the config specification used by the settings gui
  config_spec = {
    name = "nficons",
    {
      label = "use default directory icons",
      description = "when enabled does not use nonicon directory icons.",
      path = "use_default_dir_icons",
      type = "toggle",
      default = false
    },
    {
      label = "use default chevrons",
      description = "when enabled does not use nonicon expand/collapse arrow icons.",
      path = "use_default_chevrons",
      type = "toggle",
      default = false
    },
    {
      label = "draw treeview icons",
      description = "enables file related icons on the treeview.",
      path = "draw_treeview_icons",
      type = "toggle",
      default = true
    },
    {
      label = "draw tab icons",
      description = "adds file related icons to tabs.",
      path = "draw_tab_icons",
      type = "toggle",
      default = true
    }
  }
}, config.plugins.nficons)

---split a string by the given delimeter
---@param s string the string to split
---@param delimeter string delimeter without lua patterns
---@param delimeter_pattern? string optional delimeter with lua patterns
---@return table
local function split(s, delimeter, delimeter_pattern)
  if not delimeter_pattern then
    delimeter_pattern = delimeter
  end

  local result = {};
  for match in (s..delimeter):gmatch("(.-)"..delimeter_pattern) do
    table.insert(result, match);
  end
  return result;
end

-- from https://github.com/TorchedSammy/lite-xl-lspkind/blob/master/init.lua
local function load_font(name, size)
  local proc = process.start {'sh', '-c', 'fc-list | grep "' .. name ..'"'}
  if proc then
    proc:wait(process.WAIT_INFINITE)
    local out = proc:read_stdout() or ''
    local file = split(out, ':')[1]

    return renderer.font.load(file, size)
  end
end

local icon_font = load_font("Nerd Font", 21 * SCALE)
local chevron_width = icon_font:get_width("")
local previous_scale = SCALE

-- override function to change default icons for dirs, special extensions and names
local treeview_get_item_icon = treeview.get_item_icon
function treeview:get_item_icon(item, active, hovered)
  local icon, font, color = treeview_get_item_icon(self, item, active, hovered)
  if previous_scale ~= SCALE then
    icon_font:set_size(
      icon_font:get_size() * (SCALE / previous_scale)
    )
    chevron_width = icon_font:get_width("")
    previous_scale = SCALE
  end


  if not config.plugins.nficons.use_default_dir_icons then
    icon = ""
    font = icon_font
    color = style.text
    if item.type == "dir" then
      icon = item.expanded and "ﱮ" or ""
    end
  end

  local custom_icon
  if config.plugins.nficons.draw_treeview_icons then
    local known_name = nficons.filetypes[item.name:lower()]
    if known_name == nil then
      local known_extension = nficons.icons[item.name:match("^.+%.(.+)$")]
      if known_extension ~= nil then
        custom_icon = known_extension
      end
    else
      custom_icon = nficons.icons[known_name]
    end

    if custom_icon ~= nil then
      color = { common.color(custom_icon["color"]) }
      icon = custom_icon["icon"]
      font = icon_font
    end
    if active or hovered then
      color = style.accent
    end
  end

  return icon, font, color
end

-- override function to draw chevrons if setting is disabled
local treeview_draw_item_chevron = treeview.draw_item_chevron
function treeview:draw_item_chevron(item, active, hovered, x, y, w, h)
  if not config.plugins.nficons.use_default_chevrons then
    if item.type == "dir" then
      local chevron_icon = item.expanded and "" or ""
      local chevron_color = hovered and style.accent or style.text
      common.draw_text(icon_font, chevron_color, chevron_icon, nil, x, y, 0, h)
    end
    return chevron_width + style.padding.x/4
  end
  return treeview_draw_item_chevron(self, item, active, hovered, x, y, w, h)
end

-- override function to draw icons in tabs titles if setting is enabled
local node_draw_tab_title = node.draw_tab_title
function node:draw_tab_title(view, font, is_active, is_hovered, x, y, w, h)
  if config.plugins.nficons.draw_tab_icons then
    local padx = chevron_width + style.padding.x/2
    local tx = x + padx -- space for icon
    w = w - padx
    node_draw_tab_title(self, view, font, is_active, is_hovered, tx, y, w, h)
    if (view == nil) or (view.doc == nil) then return end
    local item = { type = "file", name = view.doc:get_name() }
    treeview:draw_item_icon(item, false, is_hovered, x, y, w, h)
  else
    node_draw_tab_title(self, view, font, is_active, is_hovered, x, y, w, h)
  end
end
