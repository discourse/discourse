# frozen_string_literal: true

Fabricator(:voice_agent_integration, from: "Voice::AgentIntegration") do
  name "Call assistant"
  credential_digest { SecureRandom.hex(32) }
  bot_user { Fabricate(:user, id: -1400) }
end
