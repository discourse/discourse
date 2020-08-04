# frozen_string_literal: true

class SelectableAvatarsEnabledValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(value)
    value == "f" || SiteSetting.selectable_avatars.split("\n").size > 1
  end

  def error_message
    I18n.t('site_settings.errors.empty_selectable_avatars')
  end
end
