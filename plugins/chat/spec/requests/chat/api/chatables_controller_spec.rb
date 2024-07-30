# frozen_string_literal: true

RSpec.describe Chat::Api::ChatablesController do
  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
  end

  fab!(:current_user) { Fabricate(:user) }

  describe "#index" do
    describe "without chat permissions" do
      it "errors errors for anon" do
        get "/chat/api/chatables"

        expect(response.status).to eq(403)
      end

      it "errors when user cannot chat" do
        SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:staff]
        sign_in(current_user)

        get "/chat/api/chatables"

        expect(response.status).to eq(403)
      end
    end

    describe "with chat permissions" do
      fab!(:channel_1) { Fabricate(:chat_channel) }

      before { channel_1.add(current_user) }

      it "returns results" do
        sign_in(current_user)

        get "/chat/api/chatables", params: { term: channel_1.name }

        expect(response.status).to eq(200)
        expect(response.parsed_body["category_channels"][0]["identifier"]).to eq(
          "c-#{channel_1.id}",
        )
      end
    end
  end
end
