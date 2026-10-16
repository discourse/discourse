# frozen_string_literal: true

module Voice
  class AgentBot
    USERNAME = "livekit_agent_bot"
    STORE_KEY = "livekit_agent_bot_id"

    def self.user
      id = PluginStore.get("voice", STORE_KEY).to_i
      User.find_by(id:) if id < -1
    end

    def self.ensure!
      return unless SiteSetting.voice_livekit_agent_enabled

      DistributedMutex.synchronize("voice:agent_bot") do
        user ||
          User.transaction do
            bot =
              User.create!(
                id: [User.minimum(:id).to_i, -1].min - 1,
                username: USERNAME,
                name: "LiveKit agent",
                email: "#{SecureRandom.hex(16)}@invalid.invalid",
                active: true,
                approved: true,
                trust_level: TrustLevel[1],
              )
            PluginStore.set("voice", STORE_KEY, bot.id)
            bot
          end
      end
    end

    def self.available?
      bot = user
      SiteSetting.voice_livekit_agent_enabled && Livekit.cloud? && Livekit.configured? &&
        bot&.active? && !bot.suspended?
    end
  end
end
