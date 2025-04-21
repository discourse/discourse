# frozen_string_literal: true

describe Chat::Api::ChannelsCurrentUserMembershipController do
  fab!(:current_user) { Fabricate(:user) }

  before do
    channel_1.add(current_user)
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    sign_in(current_user)
  end

  describe "#destroy" do
    describe "for a category channel" do
      fab!(:channel_1) { Fabricate(:category_channel) }

      it "works" do
        delete "/chat/api/channels/#{channel_1.id}/memberships/me/follows"

        expect(response.status).to eq(200)
        expect(channel_1.membership_for(current_user).following).to eq(false)
      end

      context "when channel is not found" do
        before { channel_1.destroy! }
        it "returns a 404" do
          delete "/chat/api/channels/-999/memberships/me/follows"

          expect(response.status).to eq(404)
        end
      end
    end

    describe "for a group direct message channel" do
      fab!(:other_user_1) { Fabricate(:user) }
      fab!(:other_user_2) { Fabricate(:user) }
      fab!(:channel_1) do
        Fabricate(:direct_message_channel, users: [current_user, other_user_1, other_user_2])
      end

      it "works" do
        delete "/chat/api/channels/#{channel_1.id}/memberships/me/follows"

        expect(response.status).to eq(200)
        expect(channel_1.membership_for(current_user).following).to eq(false)
      end
    end

    describe "for a direct message channel" do
      fab!(:other_user_1) { Fabricate(:user) }
      fab!(:channel_1) { Fabricate(:direct_message_channel, users: [current_user, other_user_1]) }

      it "works" do
        delete "/chat/api/channels/#{channel_1.id}/memberships/me/follows"

        expect(response.status).to eq(200)
        expect(channel_1.membership_for(current_user).following).to eq(false)
      end
    end
  end
end
