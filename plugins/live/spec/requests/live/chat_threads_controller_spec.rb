# frozen_string_literal: true
require "rails_helper"

RSpec.describe Live::ChatThreadsController do
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:channel) { Fabricate(:chat_channel, threading_enabled: true) }

  fab!(:room) { Fabricate(:live_room, public: true, chat_channel_id: channel.id) }

  fab!(:thread) { Fabricate(:chat_thread, channel: channel) }

  before do
    SiteSetting.live_enabled = true
    SiteSetting.live_chat_enabled = true
    SiteSetting.chat_enabled = true
    SiteSetting.live_allowed_groups =
      "#{Group::AUTO_GROUPS[:anonymous_users]}|#{Group::AUTO_GROUPS[:logged_in_users]}"
    SiteSetting.chat_allowed_groups =
      "#{Group::AUTO_GROUPS[:anonymous_users]}|#{Group::AUTO_GROUPS[:logged_in_users]}"
    # Keep the signed-in user a plain member — not a global room manager — so
    # room visibility is decided by membership, not the create-room privilege.
    SiteSetting.live_create_room_allowed_groups = Group::AUTO_GROUPS[:trust_level_4].to_s
  end

  def mark(chat_thread, live_room)
    chat_thread.upsert_custom_fields(Live::THREAD_ROOM_ID_FIELD => live_room.id)
    chat_thread
  end

  describe "#show" do
    it "requires authentication" do
      mark(thread, room)

      get "/live/chat_threads/#{thread.id}.json"

      expect(response.status).to eq(403)
    end

    context "when signed in" do
      before { sign_in(user) }

      it "returns the room behind a marked, visible session thread" do
        mark(thread, room)

        get "/live/chat_threads/#{thread.id}.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body).to eq(
          "id" => room.id,
          "slug" => room.slug,
          "name" => room.name,
          "chat_active" => false,
        )
      end

      it "reports a thread that is still the room's live session as active" do
        mark(thread, room)
        Fabricate(:chat_message, chat_channel: channel, thread: thread)
        Discourse.redis.set("voice:room:#{room.id}:chat_thread", thread.id)

        get "/live/chat_threads/#{thread.id}.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["chat_active"]).to eq(true)
      ensure
        Live::ChatSession.clear(room.id)
      end

      it "reports a thread whose session rolled over to a newer thread as inactive" do
        mark(thread, room)
        newer_thread = Fabricate(:chat_thread, channel: channel)
        Fabricate(:chat_message, chat_channel: channel, thread: newer_thread)
        Discourse.redis.set("voice:room:#{room.id}:chat_thread", newer_thread.id)

        get "/live/chat_threads/#{thread.id}.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["chat_active"]).to eq(false)
      ensure
        Live::ChatSession.clear(room.id)
      end

      it "returns 404 for a thread that was never marked as a session thread" do
        get "/live/chat_threads/#{thread.id}.json"

        expect(response.status).to eq(404)
      end

      it "returns 404 for a thread id that does not exist" do
        get "/live/chat_threads/#{Chat::Thread.maximum(:id).to_i + 1}.json"

        expect(response.status).to eq(404)
      end

      it "returns 404 when the marker points at a room linked to a different channel" do
        other_channel = Fabricate(:chat_channel, threading_enabled: true)
        other_room = Fabricate(:live_room, public: true, chat_channel_id: other_channel.id)
        mark(thread, other_room)

        get "/live/chat_threads/#{thread.id}.json"

        expect(response.status).to eq(404)
      end

      it "returns 404 for a marked thread whose room the user cannot see" do
        private_room = Fabricate(:live_room, public: false, chat_channel_id: channel.id)
        mark(thread, private_room)

        get "/live/chat_threads/#{thread.id}.json"

        expect(response.status).to eq(404)
      end

      it "returns 404 when the channel no longer has threading enabled" do
        mark(thread, room)
        channel.update!(threading_enabled: false)

        get "/live/chat_threads/#{thread.id}.json"

        expect(response.status).to eq(404)
      end

      it "returns 404 when the thread's starter message was deleted" do
        mark(thread, room)
        thread.original_message.trash!

        get "/live/chat_threads/#{thread.id}.json"

        expect(response.status).to eq(404)
      end

      it "still resolves a deleted-starter thread for someone who can moderate the channel" do
        mark(thread, room)
        thread.original_message.trash!
        sign_in(Fabricate(:admin))

        get "/live/chat_threads/#{thread.id}.json"

        expect(response.status).to eq(200)
      end

      it "returns 404 when the user cannot preview the thread's channel" do
        private_channel = Fabricate(:private_category_channel, threading_enabled: true)
        private_thread = Fabricate(:chat_thread, channel: private_channel)
        visible_room = Fabricate(:live_room, public: true, chat_channel_id: private_channel.id)
        mark(private_thread, visible_room)

        get "/live/chat_threads/#{private_thread.id}.json"

        expect(response.status).to eq(404)
      end

      it "returns 404 when live chat is disabled" do
        SiteSetting.live_chat_enabled = false
        mark(thread, room)

        get "/live/chat_threads/#{thread.id}.json"

        expect(response.status).to eq(404)
      end

      it "returns 404 when chat is disabled site-wide" do
        SiteSetting.chat_enabled = false
        mark(thread, room)

        get "/live/chat_threads/#{thread.id}.json"

        expect(response.status).to eq(404)
      end
    end
  end
end
