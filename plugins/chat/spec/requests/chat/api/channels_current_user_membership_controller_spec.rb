# frozen_string_literal: true

describe Chat::Api::ChannelsCurrentUserMembershipController do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:category_channel) }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    sign_in(current_user)
  end

  describe "#create" do
    context "when no existing membership exists" do
      it "creates a membership" do
        expect { post "/chat/api/channels/#{channel_1.id}/memberships/me" }.to change {
          Chat::UserChatChannelMembership.where(user_id: current_user.id, following: true).count
        }.by(1)
        expect(response.status).to eq(200)
        expect(response.parsed_body["membership"]["following"]).to eq(true)
        expect(response.parsed_body["membership"]["chat_channel_id"]).to eq(channel_1.id)
        expect(response.parsed_body["membership"]["user"]["id"]).to eq(current_user.id)
      end
    end

    context "when current user can’t see the channel" do
      fab!(:channel_2) { Fabricate(:private_category_channel, group: Fabricate(:group)) }

      it "fails" do
        expect { post "/chat/api/channels/#{channel_2.id}/memberships/me" }.not_to change {
          Chat::UserChatChannelMembership.where(user_id: current_user.id).count
        }
        expect(response.status).to eq(403)
      end
    end

    context "when channel is a category channel" do
      context "when current user can't write in channel" do
        fab!(:private_category_1) { Fabricate(:private_category, group: Fabricate(:group)) }
        fab!(:readonly_group_1) { Fabricate(:group) }
        fab!(:channel_2) { Fabricate(:category_channel, chatable: private_category_1) }

        before do
          Fabricate(
            :category_group,
            category: private_category_1,
            group: readonly_group_1,
            permission_type: CategoryGroup.permission_types[:readonly],
          )
          readonly_group_1.add(current_user)
        end

        it "fails" do
          expect { post "/chat/api/channels/#{channel_2.id}/memberships/me" }.not_to change {
            Chat::UserChatChannelMembership.where(user_id: current_user.id).count
          }
          expect(response.status).to eq(403)
        end
      end

      context "when current user can write in channel" do
        fab!(:private_category_1) { Fabricate(:private_category, group: Fabricate(:group)) }
        fab!(:readonly_group_1) { Fabricate(:group) }
        fab!(:channel_2) { Fabricate(:category_channel, chatable: private_category_1) }

        before do
          Fabricate(
            :category_group,
            category: private_category_1,
            group: readonly_group_1,
            permission_type: CategoryGroup.permission_types[:create_post],
          )
          readonly_group_1.add(current_user)
        end

        it "works" do
          expect { post "/chat/api/channels/#{channel_2.id}/memberships/me" }.to change {
            Chat::UserChatChannelMembership.where(user_id: current_user.id).count
          }.by(1)
          expect(response.status).to eq(200)
        end
      end
    end

    context "when an existing membership exists" do
      it "enforces 'following' to true" do
        membership_record =
          Chat::UserChatChannelMembership.create!(
            chat_channel_id: channel_1.id,
            user_id: current_user.id,
            following: false,
          )

        expect { post "/chat/api/channels/#{channel_1.id}/memberships/me" }.to change {
          membership_record.reload.following
        }.to(true).from(false)
        expect(response.status).to eq(200)
        expect(response.parsed_body["membership"]["following"]).to eq(true)
        expect(response.parsed_body["membership"]["chat_channel_id"]).to eq(channel_1.id)
        expect(response.parsed_body["membership"]["user"]["id"]).to eq(current_user.id)
      end
    end
  end

  describe "#destroy" do
    describe "success" do
      it "works" do
        delete "/chat/api/channels/#{channel_1.id}/memberships/me"

        expect(response.status).to eq(200)
      end
    end

    context "when channel is not found" do
      it "returns a 404" do
        delete "/chat/api/channels/-999/memberships/me"

        expect(response.status).to eq(404)
      end
    end
  end
end
