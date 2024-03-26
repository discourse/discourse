# frozen_string_literal: true

describe Chat::Api::ChannelsCurrentUserMembershipController do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:category_channel) }

  before do
    channel_1.add(current_user)
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    sign_in(current_user)
  end

  describe "#destroy" do
    describe "success" do
      it "works" do
        delete "/chat/api/channels/#{channel_1.id}/memberships/me/follows"

        expect(response.status).to eq(200)
        expect(channel_1.membership_for(current_user).following).to eq(false)
      end
    end

    context "when channel is not found" do
      it "returns a 404" do
        delete "/chat/api/channels/-999/memberships/me/follows"

        expect(response.status).to eq(404)
      end
    end
  end
end
