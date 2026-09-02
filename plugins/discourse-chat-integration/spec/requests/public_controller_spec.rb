# frozen_string_literal: true

RSpec.describe "Public Controller", type: :request do
  before { SiteSetting.chat_integration_enabled = true }

  describe "loading a transcript" do
    it "is able to load a transcript" do
      key = DiscourseChatIntegration::Helper.save_transcript("Some content here")

      get "/chat-transcript/#{key}.json"

      expect(response.status).to eq(200)

      expect(response.body).to eq('{"content":"Some content here"}')
    end

    it "404S for non-existent transcript" do
      key = "abcdefghijk"
      get "/chat-transcript/#{key}.json"

      expect(response.status).to eq(404)
    end
  end
end
