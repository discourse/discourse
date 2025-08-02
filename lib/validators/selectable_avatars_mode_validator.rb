# frozen_string_literal: true

class SelectableAvatarsModeValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(value)
    value == "disabled" || SiteSetting.selectable_avatars.size > 1
  end

  def error_message
    I18n.t("site_settings.errors.empty_selectable_avatars")
  end
end
