# frozen_string_literal: true

class VoiceLivekitAgentValidator
  def initialize(opts = {})
  end

  def valid_value?(value)
    return true unless value.to_s == "t" || value == true

    @error_key =
      if !Voice::Livekit.cloud? || !Voice::Livekit.configured?
        "voice_livekit_agent_requires_cloud"
      elsif User
            .where(username_lower: Voice::AgentBot::USERNAME)
            .where.not(id: Voice::AgentBot.user&.id)
            .exists?
        "voice_livekit_agent_username_taken"
      end
    @error_key.nil?
  end

  def error_message
    I18n.t("site_settings.errors.#{@error_key}") if @error_key
  end
end
