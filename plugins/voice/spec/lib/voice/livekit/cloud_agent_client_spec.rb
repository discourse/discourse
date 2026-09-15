# frozen_string_literal: true

require "rails_helper"

RSpec.describe Voice::Livekit::CloudAgentClient do
  let(:endpoint) { "https://agents.livekit.cloud/twirp/livekit.CloudAgent/ListAgents" }

  before do
    SiteSetting.voice_livekit_url = "wss://my-project-abc123.livekit.cloud"
    SiteSetting.voice_livekit_api_key = "lk_api_key"
    SiteSetting.voice_livekit_api_secret = "lk_api_secret"
    described_class.clear_cache!
  end

  describe ".list" do
    it "POSTs to the shared agents host with an agent admin token and a client version" do
      stub = stub_request(:post, endpoint).to_return(status: 200, body: { agents: [] }.to_json)

      expect(described_class.list).to eq(ok: true, agents: [])

      expect(
        stub.with do |req|
          token = req.headers["Authorization"].delete_prefix("Bearer ")
          claims = JWT.decode(token, "lk_api_secret", true, algorithm: "HS256").first

          req.body == "{}" && req.headers["X-Livekit-Cli-Version"].present? &&
            claims["iss"] == "lk_api_key" && claims["agent"] == { "admin" => true } &&
            !claims.key?("video")
        end,
      ).to have_been_requested.once
    end

    it "returns the named agents sorted, without blanks or duplicates" do
      stub_request(:post, endpoint).to_return(
        status: 200,
        body: {
          agents: [
            { agent_name: "support" },
            { agentName: "assistant" },
            { agent_name: "" },
            { agent_name: "support" },
          ],
        }.to_json,
      )

      expect(described_class.list[:agents]).to eq([{ name: "assistant" }, { name: "support" }])
    end

    it "reuses the cached list on later calls" do
      stub =
        stub_request(:post, endpoint).to_return(
          status: 200,
          body: { agents: [{ agent_name: "assistant" }] }.to_json,
        )

      2.times { expect(described_class.list[:agents]).to eq([{ name: "assistant" }]) }

      expect(stub).to have_been_requested.once
    end

    it "is unavailable outside LiveKit Cloud" do
      SiteSetting.voice_livekit_url = "wss://livekit.example.com"
      stub = stub_request(:post, /livekit.example.com|agents\./)

      expect(described_class.list).to eq(ok: false)
      expect(stub).not_to have_been_requested
    end

    it "is unavailable when the provider fails" do
      stub_request(:post, endpoint).to_return(status: 503)

      expect(described_class.list).to eq(ok: false)
    end
  end
end
