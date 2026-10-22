# frozen_string_literal: true

class LiveLivekitAgentValidator
  def initialize(opts = {})
  end

  def valid_value?(value)
    return true unless value.to_s == "t" || value == true

    @error_key =
      if !Live::Livekit.cloud? || !Live::Livekit.configured?
        "live_livekit_agent_requires_cloud"
      elsif User
            .where(username_lower: Live::AgentBot::USERNAME)
            .where.not(id: Live::AgentBot.user&.id)
            .exists?
        "live_livekit_agent_username_taken"
      end
    @error_key.nil?
  end

  def error_message
    I18n.t("site_settings.errors.#{@error_key}") if @error_key
  end
end
