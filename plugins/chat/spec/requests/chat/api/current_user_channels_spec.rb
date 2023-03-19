# frozen_string_literal: true

require "rails_helper"

describe Chat::Api::CurrentUserChannelsController do
  fab!(:current_user) { Fabricate(:user) }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
  end

  describe "#index" do
    context "as anonymous user" do
      it "returns an error" do
        get "/chat/api/channels/me"
        expect(response.status).to eq(403)
      end
    end

    context "as disallowed user" do
      before do
        SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:staff]
        sign_in(Fabricate(:user))
      end

      it "returns an error" do
        get "/chat/api/channels/me"

        expect(response.status).to eq(403)
      end
    end

    context "as allowed user" do
      fab!(:current_user) { Fabricate(:user) }

      before { sign_in(current_user) }

      it "returns public channels with memberships" do
        channel = Fabricate(:category_channel)
        channel.add(current_user)
        get "/chat/api/channels/me"

        expect(response.parsed_body["public_channels"][0]["id"]).to eq(channel.id)
      end

      it "returns limited access public channels with memberships" do
        group = Fabricate(:group)
        channel = Fabricate(:private_category_channel, group: group)
        group.add(current_user)
        channel.add(current_user)
        get "/chat/api/channels/me"

        expect(response.parsed_body["public_channels"][0]["id"]).to eq(channel.id)
      end

      it "doesn’t return unaccessible private channels" do
        group = Fabricate(:group)
        channel = Fabricate(:private_category_channel, group: group)
        channel.add(current_user) # TODO: we should error here
        get "/chat/api/channels/me"

        expect(response.parsed_body["public_channels"]).to be_blank
      end

      it "returns dm channels you are part of" do
        dm_channel = Fabricate(:direct_message_channel, users: [current_user])
        get "/chat/api/channels/me"

        expect(response.parsed_body["direct_message_channels"][0]["id"]).to eq(dm_channel.id)
      end

      it "doesn’t return dm channels from other users" do
        Fabricate(:direct_message_channel)
        get "/chat/api/channels/me"

        expect(response.parsed_body["direct_message_channels"]).to be_blank
      end

      it "includes message bus ids" do
        Fabricate(:direct_message_channel, users: [current_user])
        channel = Fabricate(:category_channel)
        channel.add(current_user)
        get "/chat/api/channels/me"

        expect(response.status).to eq(200)

        response.parsed_body["meta"]["message_bus_last_ids"].tap do |ids|
          expect(ids["channel_metadata"]).not_to eq(nil)
          expect(ids["channel_edits"]).not_to eq(nil)
          expect(ids["channel_status"]).not_to eq(nil)
          expect(ids["new_channel"]).not_to eq(nil)
          expect(ids["archive_status"]).not_to eq(nil)
        end

        response.parsed_body["public_channels"][0]["meta"]["message_bus_last_ids"].tap do |ids|
          expect(ids["new_messages"]).not_to eq(nil)
          expect(ids["new_mentions"]).not_to eq(nil)
        end

        response.parsed_body["direct_message_channels"][0]["meta"][
          "message_bus_last_ids"
        ].tap do |ids|
          expect(ids["new_messages"]).not_to eq(nil)
          expect(ids["new_mentions"]).not_to eq(nil)
        end
      end

      context "when the chatable of a channel is destroyed" do
        context "when the channel is a category" do
          it "doesn’t return the channel" do
            channel = Fabricate(:category_channel)
            channel.add(current_user)
            channel.chatable.destroy!
            get "/chat/api/channels/me"

            expect(response.status).to eq(200)
            expect(response.parsed_body["public_channels"]).to be_blank
          end
        end

        context "when the channel is a direct message" do
          it "doesn’t return the channel" do
            channel = Fabricate(:direct_message_channel, users: [current_user])
            channel.chatable.destroy!
            get "/chat/api/channels/me"

            expect(response.status).to eq(200)
            expect(response.parsed_body["direct_message_channels"]).to be_blank
          end
        end
      end
    end
  end
end
