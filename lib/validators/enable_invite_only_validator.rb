# frozen_string_literal: true

class EnableInviteOnlyValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val == "f"
    !SiteSetting.enable_discourse_connect?
  end

  def error_message
    I18n.t("site_settings.errors.discourse_connect_invite_only")
  end
end
