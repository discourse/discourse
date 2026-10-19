# frozen_string_literal: true

# Secret-authenticated TURN servers are unusable without the shared secret,
# so admins get a config-time failure instead of dead ICE entries.
class VoiceTurnSecretServersValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(value)
    value.blank? || SiteSetting.voice_turn_secret.present?
  end

  def error_message
    I18n.t("site_settings.errors.voice_turn_secret_servers_requires_secret")
  end
end
