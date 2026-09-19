# frozen_string_literal: true

# Config-time shape check for the LiveKit server URL. The URL is converted to
# HTTP(S) for server-side Twirp requests, so it must be a bare ws(s):// origin
# with a host and no credentials — and TLS is mandatory in production, both
# for the signaling WebSocket and the derived HTTPS API calls. Address-level
# SSRF protection happens at request time via FinalDestination.
class VoiceLivekitUrlValidator
  def self.acceptable?(value)
    value.present? && VoiceLivekitUrlValidator.new.valid_value?(value)
  end

  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(value)
    return true if value.blank?

    uri = URI.parse(value.to_s)
    @error_key =
      if %w[ws wss].exclude?(uri.scheme.to_s) || uri.host.blank? || uri.userinfo.present?
        "voice_livekit_url_invalid"
      elsif uri.scheme == "ws" && Rails.env.production?
        "voice_livekit_url_requires_wss"
      end
    @error_key.nil?
  rescue URI::Error
    @error_key = "voice_livekit_url_invalid"
    false
  end

  def error_message
    I18n.t("site_settings.errors.#{@error_key}") if @error_key
  end
end
