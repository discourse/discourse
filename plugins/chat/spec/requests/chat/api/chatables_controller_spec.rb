# frozen_string_literal: true

require "rails_helper"

RSpec.describe Chat::Api::ChatablesController do
  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
  end

  describe "#index" do
    fab!(:user) { Fabricate(:user, username: "johndoe", name: "John Doe") }

    describe "without chat permissions" do
      it "errors errors for anon" do
        get "/chat/api/chatables", params: { filter: "so" }
        expect(response.status).to eq(403)
      end

      it "errors when user cannot chat" do
        SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:staff]
        sign_in(user)
        get "/chat/api/chatables", params: { filter: "so" }
        expect(response.status).to eq(403)
      end
    end

    describe "with chat permissions" do
      fab!(:other_user) { Fabricate(:user, username: "janemay", name: "Jane May") }
      fab!(:admin) { Fabricate(:admin, username: "andyjones", name: "Andy Jones") }
      fab!(:category) { Fabricate(:category) }
      fab!(:chat_channel) { Fabricate(:category_channel, chatable: category) }
      fab!(:dm_chat_channel) { Fabricate(:direct_message_channel, users: [user, admin]) }

      before do
        chat_channel.update(name: "something")
        sign_in(user)
      end

      it "returns the correct channels with filter 'so'" do
        get "/chat/api/chatables", params: { filter: "so" }
        expect(response.status).to eq(200)
        expect(response.parsed_body["public_channels"][0]["id"]).to eq(chat_channel.id)
        expect(response.parsed_body["direct_message_channels"].count).to eq(0)
        expect(response.parsed_body["users"].count).to eq(0)
      end

      it "returns the correct channels with filter 'something'" do
        get "/chat/api/chatables", params: { filter: "something" }
        expect(response.status).to eq(200)
        expect(response.parsed_body["public_channels"][0]["id"]).to eq(chat_channel.id)
        expect(response.parsed_body["direct_message_channels"].count).to eq(0)
        expect(response.parsed_body["users"].count).to eq(0)
      end

      it "returns the correct channels with filter 'andyjones'" do
        get "/chat/api/chatables", params: { filter: "andyjones" }
        expect(response.status).to eq(200)
        expect(response.parsed_body["public_channels"].count).to eq(0)
        expect(response.parsed_body["direct_message_channels"][0]["id"]).to eq(dm_chat_channel.id)
        expect(response.parsed_body["users"].count).to eq(0)
      end

      it "returns the current user inside the users array if their username matches the filter too" do
        user.update!(username: "andysmith")
        get "/chat/api/chatables", params: { filter: "andy" }
        expect(response.status).to eq(200)
        expect(response.parsed_body["direct_message_channels"][0]["id"]).to eq(dm_chat_channel.id)
        expect(response.parsed_body["users"].map { |u| u["id"] }).to match_array([user.id])
      end

      it "returns no channels with a whacky filter" do
        get "/chat/api/chatables", params: { filter: "hello good sir" }
        expect(response.status).to eq(200)
        expect(response.parsed_body["public_channels"].count).to eq(0)
        expect(response.parsed_body["direct_message_channels"].count).to eq(0)
        expect(response.parsed_body["users"].count).to eq(0)
      end

      it "only returns open channels" do
        chat_channel.update(status: Chat::Channel.statuses[:closed])
        get "/chat/api/chatables", params: { filter: "so" }
        expect(response.parsed_body["public_channels"].count).to eq(0)

        chat_channel.update(status: Chat::Channel.statuses[:read_only])
        get "/chat/api/chatables", params: { filter: "so" }
        expect(response.parsed_body["public_channels"].count).to eq(0)

        chat_channel.update(status: Chat::Channel.statuses[:archived])
        get "/chat/api/chatables", params: { filter: "so" }
        expect(response.parsed_body["public_channels"].count).to eq(0)

        # Now set status to open and the channel is there!
        chat_channel.update(status: Chat::Channel.statuses[:open])
        get "/chat/api/chatables", params: { filter: "so" }
        expect(response.parsed_body["public_channels"][0]["id"]).to eq(chat_channel.id)
      end

      it "only finds users by username_lower if not enable_names" do
        SiteSetting.enable_names = false
        get "/chat/api/chatables", params: { filter: "Andy J" }
        expect(response.status).to eq(200)
        expect(response.parsed_body["public_channels"].count).to eq(0)
        expect(response.parsed_body["direct_message_channels"].count).to eq(0)

        get "/chat/api/chatables", params: { filter: "andyjones" }
        expect(response.status).to eq(200)
        expect(response.parsed_body["public_channels"].count).to eq(0)
        expect(response.parsed_body["direct_message_channels"][0]["id"]).to eq(dm_chat_channel.id)
      end

      it "only finds users by username if prioritize_username_in_ux" do
        SiteSetting.prioritize_username_in_ux = true
        get "/chat/api/chatables", params: { filter: "Andy J" }
        expect(response.status).to eq(200)
        expect(response.parsed_body["public_channels"].count).to eq(0)
        expect(response.parsed_body["direct_message_channels"].count).to eq(0)

        get "/chat/api/chatables", params: { filter: "andyjones" }
        expect(response.status).to eq(200)
        expect(response.parsed_body["public_channels"].count).to eq(0)
        expect(response.parsed_body["direct_message_channels"][0]["id"]).to eq(dm_chat_channel.id)
      end

      it "can find users by name or username if not prioritize_username_in_ux and enable_names" do
        SiteSetting.prioritize_username_in_ux = false
        SiteSetting.enable_names = true
        get "/chat/api/chatables", params: { filter: "Andy J" }
        expect(response.status).to eq(200)
        expect(response.parsed_body["public_channels"].count).to eq(0)
        expect(response.parsed_body["direct_message_channels"][0]["id"]).to eq(dm_chat_channel.id)

        get "/chat/api/chatables", params: { filter: "andyjones" }
        expect(response.status).to eq(200)
        expect(response.parsed_body["public_channels"].count).to eq(0)
        expect(response.parsed_body["direct_message_channels"][0]["id"]).to eq(dm_chat_channel.id)
      end

      it "does not return DM channels for users who do not have chat enabled" do
        admin.user_option.update!(chat_enabled: false)
        get "/chat/api/chatables", params: { filter: "andyjones" }
        expect(response.status).to eq(200)
        expect(response.parsed_body["direct_message_channels"].count).to eq(0)
      end

      xit "does not return DM channels for users who are not in the chat allowed group" do
        group = Fabricate(:group, name: "chatpeeps")
        SiteSetting.chat_allowed_groups = group.id
        GroupUser.create(user: user, group: group)
        dm_chat_channel_2 = Fabricate(:direct_message_channel, users: [user, other_user])

        get "/chat/api/chatables", params: { filter: "janemay" }
        expect(response.status).to eq(200)
        expect(response.parsed_body["direct_message_channels"].count).to eq(0)

        GroupUser.create(user: other_user, group: group)
        get "/chat/api/chatables", params: { filter: "janemay" }
        if response.status == 500
          puts "ERROR in ChatablesController spec:\n"
          puts response.body
        end
        expect(response.status).to eq(200)
        expect(response.parsed_body["direct_message_channels"][0]["id"]).to eq(dm_chat_channel_2.id)
      end

      it "returns DM channels for staff users even if they are not in chat_allowed_groups" do
        group = Fabricate(:group, name: "chatpeeps")
        SiteSetting.chat_allowed_groups = group.id
        GroupUser.create(user: user, group: group)

        get "/chat/api/chatables", params: { filter: "andyjones" }
        expect(response.status).to eq(200)
        expect(response.parsed_body["direct_message_channels"][0]["id"]).to eq(dm_chat_channel.id)
      end

      it "returns followed channels" do
        Fabricate(
          :user_chat_channel_membership,
          user: user,
          chat_channel: chat_channel,
          following: true,
        )

        get "/chat/api/chatables", params: { filter: chat_channel.name }

        expect(response.status).to eq(200)
        expect(response.parsed_body["public_channels"][0]["id"]).to eq(chat_channel.id)
      end

      it "returns not followed channels" do
        Fabricate(
          :user_chat_channel_membership,
          user: user,
          chat_channel: chat_channel,
          following: false,
        )

        get "/chat/api/chatables", params: { filter: chat_channel.name }

        expect(response.status).to eq(200)
        expect(response.parsed_body["public_channels"][0]["id"]).to eq(chat_channel.id)
      end

      describe "with 'include_cannot_chat' param" do
        fab!(:cannot_chat_user) { Fabricate(:user, username: "janeday", name: "Jane Day") }
        fab!(:chat_group) { Fabricate(:group, users: [user, other_user]) }

        before { SiteSetting.chat_allowed_groups = chat_group.id }

        it "Serializes 'cannot_chat' for user who does not have chat permissions" do
          get "/chat/api/chatables", params: { filter: "jane", include_cannot_chat: true }

          expect(response.status).to eq(200)
          expect(response.parsed_body["users"].count).to eq(2)

          cannot_chat_user_json =
            response.parsed_body["users"].detect { |u| u["id"] == cannot_chat_user.id }
          expect(cannot_chat_user_json["cannot_chat"]).to eq(true)
        end

        it "Serializes 'cannot_chat' for user who has chat disabled via user_option" do
          GroupUser.create!(user: cannot_chat_user, group: chat_group)
          cannot_chat_user.user_option.update!(chat_enabled: false)

          get "/chat/api/chatables", params: { filter: "jane", include_cannot_chat: true }

          expect(response.status).to eq(200)
          expect(response.parsed_body["users"].count).to eq(2)

          cannot_chat_user_json =
            response.parsed_body["users"].detect { |u| u["id"] == cannot_chat_user.id }
          expect(cannot_chat_user_json["cannot_chat"]).to eq(true)
        end

        it "Doesn't serialize 'cannot_chat' for users who can chat" do
          get "/chat/api/chatables", params: { filter: "jane", include_cannot_chat: true }

          expect(response.status).to eq(200)
          expect(response.parsed_body["users"].count).to eq(2)

          can_chat_json = response.parsed_body["users"].detect { |u| u["id"] == other_user.id }
          expect(can_chat_json["cannot_chat"]).to be_nil
        end
      end

      describe "with 'chatable_types' param present" do
        fab!(:other_dm_chat_channel) do
          Fabricate(:direct_message_channel, users: [user, other_user])
        end
        before { chat_channel.update(name: "jane") }

        it "can only return DMs" do
          get "/chat/api/chatables",
              params: {
                filter: "jane",
                chatable_types: ["direct_message_channel"],
              }

          expect(response.parsed_body["public_channels"].count).to eq(0)
          expect(response.parsed_body["direct_message_channels"].count).to eq(1)
          expect(response.parsed_body["users"].count).to eq(0)
        end

        it "can only return public channels" do
          get "/chat/api/chatables", params: { filter: "jane", chatable_types: ["public_channel"] }

          expect(response.parsed_body["public_channels"].count).to eq(1)
          expect(response.parsed_body["direct_message_channels"].count).to eq(0)
          expect(response.parsed_body["users"].count).to eq(0)
        end

        it "can only return users" do
          get "/chat/api/chatables", params: { filter: "jane", chatable_types: ["user"] }

          expect(response.parsed_body["public_channels"].count).to eq(0)
          expect(response.parsed_body["direct_message_channels"].count).to eq(0)
          expect(response.parsed_body["users"].count).to eq(1)
        end

        it "can return multiple types" do
          get "/chat/api/chatables",
              params: {
                filter: "jane",
                chatable_types: %w[public_channel direct_message_channel],
              }

          expect(response.parsed_body["public_channels"].count).to eq(1)
          expect(response.parsed_body["direct_message_channels"].count).to eq(1)
          expect(response.parsed_body["users"].count).to eq(0)
        end
      end
    end
  end
end
