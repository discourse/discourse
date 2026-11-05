# frozen_string_literal: true

# Refuses any LiveKit room policy other than "disabled" unless the server URL
# (a valid wss:// origin — see LiveLivekitUrlValidator), API key, and API
# secret are all present, so admins get a config-time failure instead of a
# first-join failure.
class LiveLivekitPolicyValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(value)
    return true if value == "disabled"

    @error_key =
      if !LiveLivekitUrlValidator.acceptable?(SiteSetting.live_livekit_url)
        "live_livekit_policy_requires_url"
      elsif SiteSetting.live_livekit_api_key.blank?
        "live_livekit_policy_requires_api_key"
      elsif SiteSetting.live_livekit_api_secret.blank?
        "live_livekit_policy_requires_api_secret"
      end

    @error_key.nil?
  end

  def error_message
    I18n.t("site_settings.errors.#{@error_key}") if @error_key
  end
end
