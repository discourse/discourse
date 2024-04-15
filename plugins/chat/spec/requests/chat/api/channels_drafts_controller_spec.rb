# frozen_string_literal: true

RSpec.describe Chat::Api::ChannelsDraftsController do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:chat_channel) }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    channel_1.add(current_user)
    sign_in(current_user)
  end

  describe "#create" do
    describe "success" do
      it "works" do
        post "/chat/api/channels/#{channel_1.id}/drafts", params: { data: { message: "a" } }

        expect(response.status).to eq(200)
      end
    end

    context "when user can’t create drafts" do
      before { SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:staff] }

      it "returns a 403" do
        post "/chat/api/channels/#{channel_1.id}/drafts", params: { data: { message: "a" } }

        expect(response.status).to eq(403)
        expect(response.parsed_body["errors"].first).to eq(I18n.t("invalid_access"))
      end
    end

    context "when channel is not found" do
      it "returns a 404" do
        post "/chat/api/channels/-999/drafts", params: { data: { message: "a" } }

        expect(response.status).to eq(404)
      end
    end
  end
end
