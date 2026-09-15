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

  # Mirrors LiveKit Cloud: the unfiltered listing carries ids but blank names,
  # while a lookup by id returns the dispatch name.
  def stub_catalogue(names_by_id)
    stub_request(:post, endpoint).to_return do |request|
      id = JSON.parse(request.body)["agent_id"]
      agents =
        if id
          [{ agent_id: id, agent_name: names_by_id.fetch(id) }]
        else
          names_by_id.keys.map { |agent_id| { agent_id:, agent_name: "" } }
        end
      { status: 200, body: { agents: }.to_json }
    end
  end

  describe ".list" do
    it "POSTs to the shared agents host with an agent admin token and a client version" do
      stub = stub_catalogue({})

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

    it "resolves each agent's dispatch name by id, sorted and without blanks or duplicates" do
      stub =
        stub_catalogue(
          "CA_1" => "support",
          "CA_2" => "assistant",
          "CA_3" => "",
          "CA_4" => "support",
        )

      expect(described_class.list[:agents]).to eq([{ name: "assistant" }, { name: "support" }])

      expect(stub).to have_been_requested.times(5)
      expect(
        a_request(:post, endpoint).with(body: { agent_id: "CA_2" }.to_json),
      ).to have_been_made.once
    end

    it "reuses the cached list on later calls" do
      stub = stub_catalogue("CA_1" => "assistant")

      2.times { expect(described_class.list[:agents]).to eq([{ name: "assistant" }]) }

      expect(stub).to have_been_requested.twice
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
