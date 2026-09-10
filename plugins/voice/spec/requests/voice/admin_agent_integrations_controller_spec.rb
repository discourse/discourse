# frozen_string_literal: true

require "rails_helper"

RSpec.describe Voice::AdminAgentIntegrationsController do
  fab!(:admin)
  fab!(:room, :voice_room)
  fab!(:bot) { Fabricate(:user, id: -1400) }
  let(:attributes) do
    { name: "Call assistant", bot_user_id: bot.id, room_ids: [room.id], role: "speaker" }
  end
  before { SiteSetting.voice_enabled = true }

  describe "#create" do
    it "requires administrator access" do
      sign_in(Fabricate(:moderator))
      post "/admin/plugins/voice/agent-integrations.json", params: { integration: attributes }
      expect(response.status).to eq(404)
      expect(Voice::AgentIntegration.count).to eq(0)
    end

    it "reveals a credential once and persists only its digest" do
      sign_in(admin)
      post "/admin/plugins/voice/agent-integrations.json", params: { integration: attributes }
      expect(response.status).to eq(201)
      credential = response.parsed_body.fetch("credential")
      integration = Voice::AgentIntegration.sole
      expect(integration.credential_digest).to eq(Digest::SHA256.hexdigest(credential))
      expect(integration.rooms).to contain_exactly(room)
      expect(response.parsed_body.dig("integration", "role")).to eq("speaker")

      get "/admin/plugins/voice/agent-integrations.json"
      expect(response.status).to eq(200)
      expect(response.body).not_to include(credential)
      expect(response.body).not_to include(integration.credential_digest)
    end

    it "rejects human and system accounts" do
      sign_in(admin)
      [admin, Discourse.system_user].each do |invalid_bot|
        post "/admin/plugins/voice/agent-integrations.json",
             params: {
               integration: attributes.merge(bot_user_id: invalid_bot.id),
             }
        expect(response.status).to eq(400)
      end
      expect(Voice::AgentIntegration.count).to eq(0)
    end
  end

  describe "#rotate" do
    it "replaces credentials without exposing the previous secret" do
      sign_in(admin)
      integration = Fabricate(:voice_agent_integration, bot_user: bot, rooms: [room])
      previous = Voice::AgentManager.create_credential!(integration)
      post "/admin/plugins/voice/agent-integrations/#{integration.id}/rotate.json"
      expect(response.status).to eq(200)
      expect(Voice::AgentManager.authenticate(previous)).to be_nil
      expect(Voice::AgentManager.authenticate(response.parsed_body.fetch("credential"))).to eq(
        integration,
      )
    end
  end

  describe "#restore_exclusion" do
    it "clears a room exclusion without changing other room exclusions" do
      sign_in(admin)
      other_room = Fabricate(:voice_room)
      integration = Fabricate(:voice_agent_integration, bot_user: bot, rooms: [room, other_room])
      [room, other_room].each do |excluded_room|
        Voice::AgentManager.exclude!(room: excluded_room, user_id: bot.id)
      end

      delete "/admin/plugins/voice/agent-integrations/#{integration.id}/exclusions/#{room.id}.json"

      expect(response.status).to eq(204)
      expect(integration.excluded_from?(room)).to eq(false)
      expect(integration.excluded_from?(other_room)).to eq(true)
    end
  end
end
