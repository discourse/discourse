# frozen_string_literal: true

require "rails_helper"

RSpec.describe Voice::AgentBot do
  before do
    SiteSetting.voice_enabled = true
    SiteSetting.voice_livekit_url = "wss://test.livekit.cloud"
    SiteSetting.voice_livekit_api_key = "key"
    SiteSetting.voice_livekit_api_secret = "secret"
  end

  describe ".ensure!" do
    it "creates a bot when enabled and reuses it when enabled again" do
      SiteSetting.voice_livekit_agent_enabled = true
      bot = described_class.user

      expect(bot.username).to eq("livekit_agent_bot")
      expect(bot).to be_bot
      expect(bot).to be_active
      expect(bot).not_to be_staff
      expect(described_class).to be_available
      SiteSetting.voice_livekit_agent_enabled = false
      expect(described_class).not_to be_available
      SiteSetting.voice_livekit_agent_enabled = true
      expect(described_class.user.id).to eq(bot.id)
    end

    it "refuses to take over an existing username" do
      user = Fabricate(:user, username: "livekit_agent_bot")

      expect { SiteSetting.voice_livekit_agent_enabled = true }.to raise_error(
        Discourse::InvalidParameters,
      )
      expect(described_class.user).to be_nil
      expect(user.reload).not_to be_bot
    end

    it "requires a configured Cloud project" do
      SiteSetting.voice_livekit_url = "wss://livekit.example.com"
      expect { SiteSetting.voice_livekit_agent_enabled = true }.to raise_error(
        Discourse::InvalidParameters,
      )
      expect(described_class.user).to be_nil
    end
  end
end
