# frozen_string_literal: true

RSpec.describe Chat::Api::ChannelsMembershipsController do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:other_user) { Fabricate(:user) }
  fab!(:channel_1) do
    Fabricate(:direct_message_channel, group: true, users: [current_user, other_user])
  end

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    channel_1.add(current_user)
    channel_1.add(other_user)
    sign_in(current_user)
  end

  describe "#create" do
    describe "success" do
      it "works" do
        add_users_to_channel(current_user, channel_1)
        post "/chat/api/channels/#{channel_1.id}/memberships",
             params: {
               usernames: [Fabricate(:user).username],
             }

        expect(response.status).to eq(200)
      end
    end

    context "when users can't be added" do
      before do
        channel_1.chatable.update(group: false)
        channel_1.update(messages_count: 1)
      end

      it "returns a 422" do
        post "/chat/api/channels/#{channel_1.id}/memberships",
             params: {
               usernames: [Fabricate(:user).username],
             }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"].first).to eq(
          I18n.t("chat.errors.users_cant_be_added_to_channel"),
        )
      end
    end

    context "when channel is not found" do
      before { channel_1.chatable.update!(group: false) }

      it "returns a 404" do
        get "/chat/api/channels/-999/messages", params: { usernames: [Fabricate(:user).username] }

        expect(response.status).to eq(404)
      end
    end
  end

  describe "#destroy" do
    context "when acting user is an admin" do
      let(:current_user) { Fabricate(:admin) }

      describe "success" do
        it "works" do
          delete "/chat/api/channels/#{channel_1.id}/memberships/#{other_user.id}"

          expect(response.status).to eq(200)
        end
      end

      context "when channel is not found" do
        it "returns a 404" do
          delete "/chat/api/channels/-999/memberships/#{other_user.id}"

          expect(response.status).to eq(404)
        end
      end

      context "when target user is not found" do
        it "returns a 404" do
          delete "/chat/api/channels/#{channel_1.id}/memberships/31337"

          expect(response.status).to eq(404)
        end
      end
    end

    context "when acting user is not an admin" do
      it "returns a 403" do
        delete "/chat/api/channels/#{channel_1.id}/memberships/#{other_user.id}"

        expect(response.status).to eq(403)
      end
    end
  end
end
