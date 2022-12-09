# frozen_string_literal: true

require "rails_helper"

describe Chat::Api::ChatChannelsController do
  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
  end

  describe "#index" do
    context "as anonymous user" do
      it "returns a 403" do
        get "/chat/api/chat_channels.json"
        expect(response.status).to eq(403)
      end
    end

    describe "params" do
      fab!(:opened_channel) { Fabricate(:category_channel, name: "foo") }
      fab!(:closed_channel) { Fabricate(:category_channel, name: "bar", status: :closed) }

      before { sign_in(Fabricate(:user)) }

      it "returns all channels by default" do
        get "/chat/api/chat_channels.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body.length).to eq(2)
      end

      it "returns serialized channels " do
        get "/chat/api/chat_channels.json"

        expect(response.status).to eq(200)
        response.parsed_body.each do |channel|
          expect(channel).to match_response_schema("category_chat_channel")
        end
      end

      describe "filter" do
        it "returns channels filtered by name" do
          get "/chat/api/chat_channels.json?filter=foo"

          expect(response.status).to eq(200)
          results = response.parsed_body
          expect(results.length).to eq(1)
          expect(results[0]["title"]).to eq("foo")
        end
      end

      describe "status" do
        it "returns channels with the status" do
          get "/chat/api/chat_channels.json?status=closed"

          expect(response.status).to eq(200)
          results = response.parsed_body
          expect(results.length).to eq(1)
          expect(results[0]["status"]).to eq("closed")
        end
      end

      describe "limit" do
        it "returns a number of channel equal to the limit" do
          get "/chat/api/chat_channels.json?limit=1"

          expect(response.status).to eq(200)
          results = response.parsed_body
          expect(results.length).to eq(1)
        end
      end
      describe "offset" do
        it "returns channels from the offset" do
          get "/chat/api/chat_channels.json?offset=2"

          expect(response.status).to eq(200)
          results = response.parsed_body
          expect(results.length).to eq(0)
        end
      end
    end
  end

  describe "#create" do
    fab!(:admin) { Fabricate(:admin) }
    fab!(:category) { Fabricate(:category) }

    let(:params) do
      {
        type: category.class.name,
        id: category.id,
        name: "channel name",
        description: "My new channel",
      }
    end

    before { sign_in(admin) }

    it "creates a channel associated to a category" do
      put "/chat/chat_channels.json", params: params

      new_channel = ChatChannel.last

      expect(new_channel.name).to eq(params[:name])
      expect(new_channel.description).to eq(params[:description])
      expect(new_channel.chatable_type).to eq(category.class.name)
      expect(new_channel.chatable_id).to eq(category.id)
    end

    it "creates a channel sets auto_join_users to false by default" do
      put "/chat/chat_channels.json", params: params

      new_channel = ChatChannel.last

      expect(new_channel.auto_join_users).to eq(false)
    end

    it "creates a channel with auto_join_users set to true" do
      put "/chat/chat_channels.json", params: params.merge(auto_join_users: true)

      new_channel = ChatChannel.last

      expect(new_channel.auto_join_users).to eq(true)
    end

    describe "triggers the auto-join process" do
      fab!(:chatters_group) { Fabricate(:group) }
      fab!(:user) { Fabricate(:user, last_seen_at: 15.minute.ago) }

      before do
        Jobs.run_immediately!
        Fabricate(:category_group, category: category, group: chatters_group)
        chatters_group.add(user)
      end

      it "joins the user when auto_join_users is true" do
        put "/chat/chat_channels.json", params: params.merge(auto_join_users: true)

        created_channel_id = response.parsed_body.dig("chat_channel", "id")
        membership_exists =
          UserChatChannelMembership.find_by(
            user: user,
            chat_channel_id: created_channel_id,
            following: true,
          )

        expect(membership_exists).to be_present
      end

      it "doesn't join the user when auto_join_users is false" do
        put "/chat/chat_channels.json", params: params.merge(auto_join_users: false)

        created_channel_id = response.parsed_body.dig("chat_channel", "id")
        membership_exists =
          UserChatChannelMembership.find_by(
            user: user,
            chat_channel_id: created_channel_id,
            following: true,
          )

        expect(membership_exists).to be_nil
      end
    end
  end

  describe "#update" do
    include_examples "channel access example", :put

    context "when user can’t edit channel" do
      fab!(:chat_channel) { Fabricate(:category_channel) }

      before { sign_in(Fabricate(:user)) }

      it "returns a 403" do
        put "/chat/api/chat_channels/#{chat_channel.id}.json"

        expect(response.status).to eq(403)
      end
    end

    context "when user provided invalid params" do
      fab!(:chat_channel) { Fabricate(:category_channel, user_count: 10) }

      before { sign_in(Fabricate(:admin)) }

      it "doesn’t change invalid properties" do
        put "/chat/api/chat_channels/#{chat_channel.id}.json", params: { user_count: 40 }

        expect(chat_channel.reload.user_count).to eq(10)
      end
    end

    context "when user provided an empty name" do
      fab!(:user) { Fabricate(:admin) }
      fab!(:chat_channel) do
        Fabricate(:category_channel, name: "something", description: "something else")
      end

      before { sign_in(user) }

      it "nullifies the field and doesn’t store an empty string" do
        put "/chat/api/chat_channels/#{chat_channel.id}.json", params: { name: "  " }

        expect(chat_channel.reload.name).to be_nil
      end

      it "doesn’t nullify the description" do
        put "/chat/api/chat_channels/#{chat_channel.id}.json", params: { name: "  " }

        expect(chat_channel.reload.description).to eq("something else")
      end
    end

    context "when user provides an empty description" do
      fab!(:user) { Fabricate(:admin) }
      fab!(:chat_channel) do
        Fabricate(:category_channel, name: "something else", description: "something")
      end

      before { sign_in(user) }

      it "nullifies the field and doesn’t store an empty string" do
        put "/chat/api/chat_channels/#{chat_channel.id}.json", params: { description: "  " }

        expect(chat_channel.reload.description).to be_nil
      end

      it "doesn’t nullify the name" do
        put "/chat/api/chat_channels/#{chat_channel.id}.json", params: { description: "  " }

        expect(chat_channel.reload.name).to eq("something else")
      end
    end

    context "when channel is a direct message channel" do
      fab!(:user) { Fabricate(:admin) }
      fab!(:chat_channel) { Fabricate(:direct_message_channel) }

      before { sign_in(user) }

      it "raises a 403" do
        put "/chat/api/chat_channels/#{chat_channel.id}.json"

        expect(response.status).to eq(403)
      end
    end

    context "when user provides valid params" do
      fab!(:user) { Fabricate(:admin) }
      fab!(:chat_channel) { Fabricate(:category_channel) }

      before { sign_in(user) }

      it "sets properties" do
        put "/chat/api/chat_channels/#{chat_channel.id}.json",
            params: {
              name: "joffrey",
              description: "cat owner",
            }

        expect(chat_channel.reload.name).to eq("joffrey")
        expect(chat_channel.reload.description).to eq("cat owner")
      end

      it "publishes an update" do
        messages =
          MessageBus.track_publish("/chat/channel-edits") do
            put "/chat/api/chat_channels/#{chat_channel.id}.json"
          end

        expect(messages[0].data[:chat_channel_id]).to eq(chat_channel.id)
      end

      it "returns a valid chat channel" do
        put "/chat/api/chat_channels/#{chat_channel.id}.json"

        expect(response.parsed_body).to match_response_schema("category_chat_channel")
      end

      describe "when updating allow_channel_wide_mentions" do
        it "sets the new value" do
          put "/chat/api/chat_channels/#{chat_channel.id}.json",
              params: {
                allow_channel_wide_mentions: false,
              }

          expect(response.parsed_body["allow_channel_wide_mentions"]).to eq(false)
        end
      end

      describe "Updating a channel to add users automatically" do
        it "sets the channel to auto-update users automatically" do
          put "/chat/api/chat_channels/#{chat_channel.id}.json", params: { auto_join_users: true }

          expect(response.parsed_body["auto_join_users"]).to eq(true)
        end

        it "tells staff members to slow down when toggling auto-update multiple times" do
          RateLimiter.enable

          put "/chat/api/chat_channels/#{chat_channel.id}.json", params: { auto_join_users: true }
          put "/chat/api/chat_channels/#{chat_channel.id}.json", params: { auto_join_users: false }
          put "/chat/api/chat_channels/#{chat_channel.id}.json", params: { auto_join_users: true }

          expect(response.status).to eq(429)
        end

        describe "triggers the auto-join process" do
          fab!(:chatters_group) { Fabricate(:group) }
          fab!(:another_user) { Fabricate(:user, last_seen_at: 15.minute.ago) }

          before do
            Jobs.run_immediately!
            Fabricate(:category_group, category: chat_channel.chatable, group: chatters_group)
            chatters_group.add(another_user)
          end

          it "joins the user when auto_join_users is true" do
            put "/chat/api/chat_channels/#{chat_channel.id}.json", params: { auto_join_users: true }

            created_channel_id = response.parsed_body["id"]
            membership_exists =
              UserChatChannelMembership.find_by(
                user: another_user,
                chat_channel_id: created_channel_id,
                following: true,
              )

            expect(membership_exists).to be_present
          end

          it "doesn't join the user when auto_join_users is false" do
            put "/chat/api/chat_channels/#{chat_channel.id}.json",
                params: {
                  auto_join_users: false,
                }

            created_channel_id = response.parsed_body["id"]
            membership_exists =
              UserChatChannelMembership.find_by(
                user: another_user,
                chat_channel_id: created_channel_id,
                following: true,
              )

            expect(membership_exists).to be_nil
          end
        end
      end
    end
  end
end
