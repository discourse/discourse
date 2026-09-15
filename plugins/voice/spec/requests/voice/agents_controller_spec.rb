# frozen_string_literal: true

require "rails_helper"

RSpec.describe Voice::AgentsController do
  fab!(:admin)
  fab!(:moderator)

  before do
    SiteSetting.voice_enabled = true
    SiteSetting.voice_livekit_url = "wss://test.livekit.cloud"
    SiteSetting.voice_livekit_api_key = "key"
    SiteSetting.voice_livekit_api_secret = "secret"
    SiteSetting.voice_livekit_agent_enabled = true
    Voice::Livekit::CloudAgentClient.clear_cache!
    catalogue = { "CA_2" => "support", "CA_1" => "assistant", "CA_3" => "" }
    @list =
      stub_request(
        :post,
        "https://agents.livekit.cloud/twirp/livekit.CloudAgent/ListAgents",
      ).to_return do |request|
        id = JSON.parse(request.body)["agent_id"]
        agents =
          if id
            [{ agent_id: id, agent_name: catalogue.fetch(id) }]
          else
            catalogue.keys.map { |agent_id| { agent_id:, agent_name: "" } }
          end
        { status: 200, body: { agents: }.to_json }
      end
  end

  describe "#index" do
    it "lists the named deployed agents for a member of the invite groups" do
      SiteSetting.voice_livekit_agent_invite_allowed_groups =
        "#{Group::AUTO_GROUPS[:admins]}|#{Group::AUTO_GROUPS[:moderators]}"
      sign_in(moderator)

      get "/voice/agents.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["agents"]).to eq(
        [{ "name" => "assistant" }, { "name" => "support" }],
      )
    end

    it "rejects users outside the invite groups" do
      sign_in(moderator)

      get "/voice/agents.json"

      expect(response.status).to eq(403)
      expect(@list).not_to have_been_requested
    end

    it "rejects requests while the agent feature is disabled" do
      SiteSetting.voice_livekit_agent_enabled = false
      sign_in(admin)

      get "/voice/agents.json"

      expect(response.status).to eq(403)
      expect(@list).not_to have_been_requested
    end

    it "reports a provider failure" do
      stub_request(
        :post,
        "https://agents.livekit.cloud/twirp/livekit.CloudAgent/ListAgents",
      ).to_return(status: 503)
      sign_in(admin)

      get "/voice/agents.json"

      expect(response.status).to eq(503)
      expect(response.parsed_body["errors"]).to eq([I18n.t("voice.errors.agent_list_failed")])
    end
  end
end
