# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseAi::Discord::Bot::Search do
  let(:interaction_body) do
    { data: { options: [{ value: "test query" }] }, token: "interaction_token" }.to_json.to_s
  end
  let(:search) { described_class.new(interaction_body) }

  before do
    enable_current_plugin

    stub_request(:post, "https://discord.com/api/webhooks//interaction_token").with(
      body:
        "{\"content\":\"Here are the top search results for your query:\\n\\n1. [Title](\\u003chttp://test.localhost/link\\u003e)\\n\\n\"}",
    ).to_return(status: 200, body: "{}", headers: {})

    # Stub the create_reply method
    allow(search).to receive(:create_reply)
  end

  describe "#handle_interaction!" do
    it "creates a reply with search results" do
      allow_any_instance_of(DiscourseAi::Personas::Tools::Search).to receive(:invoke).and_return(
        { rows: [%w[Title /link]] },
      )
      search.handle_interaction!
      expect(search).to have_received(:create_reply).with(/Here are the top search results/)
    end
  end
end
