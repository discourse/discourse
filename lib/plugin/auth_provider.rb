class Plugin::AuthProvider

  def self.auth_attributes
    [:glyph, :background_color, :title, :message, :frame_width, :frame_height, :authenticator,
     :title_setting, :enabled_setting, :full_screen_login, :custom_url]
  end

  attr_accessor(*auth_attributes)

  def name
    authenticator.name
  end

  def to_json
    result = {name: name}
    result['customUrl'] = custom_url if custom_url
    result['titleOverride'] = title if title
    result['titleSetting'] = title_setting if title_setting
    result['enabledSetting'] = enabled_setting if enabled_setting
    result['messageOverride'] = message if message
    result['frameWidth'] = frame_width if frame_width
    result['frameHeight'] = frame_height if frame_height
    result['fullScreenLogin'] = full_screen_login if full_screen_login
    result.to_json
  end

end
