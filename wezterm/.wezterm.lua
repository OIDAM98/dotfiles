local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.font = wezterm.font 'Iosevka Term SS04'
config.font_size = 20.0

function get_appearance()
  if wezterm.gui then
    return wezterm.gui.get_appearance()
  end
  return 'Dark'
end

function scheme_for_appearance(appearance)
  if appearance:find 'Dark' then
    return 'Argonaut'
  else
    return 'Brewer (light) (terminal.sexy)'
  end
end


config.color_scheme = scheme_for_appearance(get_appearance())

config.window_decorations = "RESIZE"
config.window_background_opacity = 0.85
config.macos_window_background_blur = 8

return config
