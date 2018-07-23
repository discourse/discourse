class Plugin::AuthProvider

  def self.auth_attributes
    [:glyph, :background_color, :pretty_name, :title, :message, :frame_width, :frame_height, :authenticator,
     :pretty_name_setting, :title_setting, :enabled_setting, :full_screen_login, :custom_url]
  end

  attr_accessor(*auth_attributes)

  def name
    authenticator.name
  end

  def to_json
    result = { name: name }
    result['customUrl'] = custom_url if custom_url
    result['prettyNameOverride'] = pretty_name || name
    result['titleOverride'] = title if title
    result['titleSetting'] = title_setting if title_setting
    result['prettyNameSetting'] = pretty_name_setting if pretty_name_setting
    result['enabledSetting'] = enabled_setting if enabled_setting
    result['messageOverride'] = message if message
    result['frameWidth'] = frame_width if frame_width
    result['frameHeight'] = frame_height if frame_height
    result['fullScreenLogin'] = full_screen_login if full_screen_login
    result.to_json
  end

end
