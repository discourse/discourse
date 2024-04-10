# frozen_string_literal: true

describe Chat::Api::CurrentUserChannelsController do
  fab!(:current_user) { Fabricate(:user) }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
  end

  describe "#index" do
    context "as anonymous user" do
      it "returns an error" do
        get "/chat/api/me/channels"
        expect(response.status).to eq(403)
      end
    end

    context "as disallowed user" do
      before do
        SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:staff]
        sign_in(Fabricate(:user))
      end

      it "returns an error" do
        get "/chat/api/me/channels"

        expect(response.status).to eq(403)
      end
    end

    context "as allowed user" do
      fab!(:current_user) { Fabricate(:user) }

      before { sign_in(current_user) }

      it "returns public channels with memberships" do
        channel = Fabricate(:category_channel)
        channel.add(current_user)
        get "/chat/api/me/channels"

        expect(response.parsed_body["public_channels"][0]["id"]).to eq(channel.id)
      end
    end
  end
end
