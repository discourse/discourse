# frozen_string_literal: true

require "rails_helper"

RSpec.describe Chat::Api::ChannelThreadsController do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:public_channel) { Fabricate(:chat_channel, threading_enabled: true) }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    Group.refresh_automatic_groups!
    sign_in(current_user)
  end

  describe "show" do
    context "when thread does not exist" do
      fab!(:thread) do
        Fabricate(
          :chat_thread,
          original_message: Fabricate(:chat_message, chat_channel: public_channel),
        )
      end

      it "returns 404" do
        thread.destroy!
        get "/chat/api/channels/#{thread.channel_id}/threads/#{thread.id}"
        expect(response.status).to eq(404)
      end
    end

    context "when thread exists" do
      fab!(:thread) do
        Fabricate(
          :chat_thread,
          original_message: Fabricate(:chat_message, chat_channel: public_channel),
        )
      end

      it "works" do
        get "/chat/api/channels/#{thread.channel_id}/threads/#{thread.id}"
        expect(response.status).to eq(200)
        expect(response.parsed_body["thread"]["id"]).to eq(thread.id)
      end

      context "when the channel_id does not match the thread id" do
        fab!(:other_channel) { Fabricate(:chat_channel) }

        it "returns 404" do
          get "/chat/api/channels/#{other_channel.id}/threads/#{thread.id}"
          expect(response.status).to eq(404)
        end
      end

      context "when channel does not have threading enabled" do
        before { thread.channel.update!(threading_enabled: false) }

        it "returns 404" do
          get "/chat/api/channels/#{thread.channel_id}/threads/#{thread.id}"
          expect(response.status).to eq(404)
        end
      end

      context "when user cannot access the channel" do
        before do
          thread.channel.update!(chatable: Fabricate(:private_category, group: Fabricate(:group)))
        end

        it "returns 403" do
          get "/chat/api/channels/#{thread.channel_id}/threads/#{thread.id}"
          expect(response.status).to eq(403)
        end
      end

      context "when user cannot chat" do
        before { SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:trust_level_4] }

        it "returns 403" do
          get "/chat/api/channels/#{thread.channel_id}/threads/#{thread.id}"
          expect(response.status).to eq(403)
        end
      end
    end
  end

  describe "index" do
    fab!(:thread_1) { Fabricate(:chat_thread, channel: public_channel) }
    fab!(:thread_2) { Fabricate(:chat_thread, channel: public_channel) }
    fab!(:thread_3) { Fabricate(:chat_thread, channel: public_channel) }
    fab!(:message_1) do
      Fabricate(
        :chat_message,
        user: current_user,
        chat_channel: public_channel,
        thread: thread_1,
        created_at: 10.minutes.ago,
      )
    end
    fab!(:message_2) do
      Fabricate(
        :chat_message,
        user: current_user,
        chat_channel: public_channel,
        thread: thread_3,
        created_at: 2.seconds.ago,
      )
    end

    before do
      thread_1.add(current_user)
      thread_3.add(current_user)
    end

    it "returns the threads the user has sent messages in for the channel" do
      get "/chat/api/channels/#{public_channel.id}/threads"
      expect(response.status).to eq(200)
      expect(response.parsed_body["threads"].map { |thread| thread["id"] }).to eq(
        [thread_3.id, thread_1.id],
      )
    end

    it "has preloaded chat mentions and users for the thread original message" do
      thread_1.original_message.update!(
        message: "@#{current_user.username} hello and @#{thread_2.original_message_user.username}!",
      )
      thread_1.original_message.rebake!
      thread_1.original_message.create_mentions

      get "/chat/api/channels/#{public_channel.id}/threads"
      expect(response.status).to eq(200)
      expect(
        response.parsed_body["threads"]
          .find { |thread| thread["id"] == thread_1.id }
          .dig("original_message", "mentioned_users"),
      ).to eq(
        [
          {
            "avatar_template" => User.system_avatar_template(current_user.username),
            "id" => current_user.id,
            "name" => current_user.name,
            "username" => current_user.username,
          },
          {
            "avatar_template" =>
              User.system_avatar_template(thread_2.original_message_user.username),
            "id" => thread_2.original_message_user.id,
            "name" => thread_2.original_message_user.name,
            "username" => thread_2.original_message_user.username,
          },
        ],
      )
    end

    context "when the channel is not accessible to the useer" do
      before do
        public_channel.update!(chatable: Fabricate(:private_category, group: Fabricate(:group)))
      end

      it "returns 404" do
        get "/chat/api/channels/#{public_channel.id}/threads"
        expect(response.status).to eq(403)
      end
    end

    context "when channel does not have threading enabled" do
      before { public_channel.update!(threading_enabled: false) }

      it "returns 404" do
        get "/chat/api/channels/#{public_channel.id}/threads"
        expect(response.status).to eq(404)
      end
    end
  end

  describe "update" do
    let(:title) { "New title" }
    let(:params) { { title: title } }
    fab!(:thread) do
      Fabricate(:chat_thread, channel: public_channel, original_message_user: current_user)
    end

    context "when thread does not exist" do
      it "returns 404" do
        thread.destroy!
        put "/chat/api/channels/#{thread.channel_id}/threads/#{thread.id}", params: params
        expect(response.status).to eq(404)
      end
    end

    context "when thread exists" do
      it "updates the title" do
        put "/chat/api/channels/#{thread.channel_id}/threads/#{thread.id}", params: params
        expect(response.status).to eq(200)
        expect(thread.reload.title).to eq(title)
      end

      context "when user cannot view the channel" do
        before { thread.update!(channel: Fabricate(:private_category_channel)) }

        it "returns 403" do
          put "/chat/api/channels/#{thread.channel_id}/threads/#{thread.id}", params: params
          expect(response.status).to eq(403)
        end
      end

      context "when the user is not the original message user" do
        before { thread.update!(original_message_user: Fabricate(:user)) }

        it "returns 403" do
          put "/chat/api/channels/#{thread.channel_id}/threads/#{thread.id}", params: params
          expect(response.status).to eq(403)
        end
      end

      context "when the title is too long" do
        let(:title) { "x" * Chat::Thread::MAX_TITLE_LENGTH + "x" }

        it "returns 400" do
          put "/chat/api/channels/#{thread.channel_id}/threads/#{thread.id}", params: params
          expect(response.status).to eq(400)
          expect(response.parsed_body["errors"]).to eq(
            ["Title is too long (maximum is #{Chat::Thread::MAX_TITLE_LENGTH} characters)"],
          )
        end
      end
    end

    context "when channel does not have threading enabled" do
      before { public_channel.update!(threading_enabled: false) }

      it "returns 404" do
        put "/chat/api/channels/#{thread.channel_id}/threads/#{thread.id}", params: params
        expect(response.status).to eq(404)
      end
    end
  end
end
