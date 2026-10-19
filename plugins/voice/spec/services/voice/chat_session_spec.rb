# frozen_string_literal: true

require "rails_helper"
require_relative "../../../db/migrate/20241107000000_create_voice_rooms"
require_relative "../../../db/migrate/20260612135211_add_video_enabled_to_voice_rooms"
require_relative "../../../db/migrate/20260630183841_add_chat_settings_to_voice_rooms"

RSpec.describe Voice::ChatSession do
  before do
    ActiveRecord::Migration.suppress_messages do
      CreateVoiceRooms.new.change unless ActiveRecord::Base.connection.table_exists?(:voice_rooms)
      unless ActiveRecord::Base.connection.column_exists?(:voice_rooms, :video_enabled)
        AddVideoEnabledToVoiceRooms.new.change
      end
      unless ActiveRecord::Base.connection.column_exists?(:voice_rooms, :chat_channel_id)
        AddChatSettingsToVoiceRooms.new.change
      end
    end
    Voice::Room.reset_column_information
  end

  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:other) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:channel) { Fabricate(:chat_channel, threading_enabled: true) }
  fab!(:room) { Fabricate(:voice_room, public: true) }

  before do
    SiteSetting.voice_enabled = true
    SiteSetting.voice_chat_enabled = true
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups =
      "#{Group::AUTO_GROUPS[:anonymous_users]}|#{Group::AUTO_GROUPS[:logged_in_users]}"
    room.update!(chat_channel_id: channel.id, chat_idle_minutes: 15)
    described_class.clear(room.id)
  end

  after { described_class.clear(room.id) }

  def live_thread(state = described_class.state(room))
    ::Chat::Thread.find(state[:thread_id])
  end

  def post_reply!(thread_id, poster, text)
    result =
      ::Chat::CreateMessage.call(
        guardian: poster.guardian,
        params: {
          chat_channel_id: channel.id,
          thread_id: thread_id,
          message: text,
        },
        options: {
          enforce_membership: true,
        },
      )
    raise "reply failed: #{Service::StepsInspector.new(result).inspect}" unless result.success?
    result.message_instance
  end

  describe ".available_for?" do
    it "is false without a linked channel" do
      room.update!(chat_channel_id: nil)
      expect(described_class.available_for?(room, user.guardian)).to eq(false)
    end

    it "is false when chat is disabled" do
      SiteSetting.chat_enabled = false
      expect(described_class.available_for?(room, user.guardian)).to eq(false)
    end

    it "is true with a linked channel and a chat-allowed user" do
      expect(described_class.available_for?(room, user.guardian)).to eq(true)
    end
  end

  describe ".available_for_rooms" do
    it "loads linked channels once and returns availability by room" do
      other_channel = Fabricate(:chat_channel, threading_enabled: true)
      other_room = Fabricate(:voice_room, public: true, chat_channel_id: other_channel.id)
      unlinked_room = Fabricate(:voice_room, public: true)

      availability = nil
      queries =
        track_sql_queries do
          availability =
            described_class.available_for_rooms([room, other_room, unlinked_room], user.guardian)
        end

      expect(availability).to eq(room.id => true, other_room.id => true, unlinked_room.id => false)
      expect(queries.grep(/FROM "chat_channels"/).size).to eq(1)
    end

    it "denies a channel in a category the user cannot access" do
      restricted_channel =
        Fabricate(:private_category_channel, group: Fabricate(:group), threading_enabled: true)
      restricted_room = Fabricate(:voice_room, public: true, chat_channel_id: restricted_channel.id)

      availability = described_class.available_for_rooms([room, restricted_room], user.guardian)

      expect(availability).to eq(room.id => true, restricted_room.id => false)
    end
  end

  describe ".state" do
    it "returns the channel with no thread before a session starts" do
      expect(described_class.state(room)).to eq({ channel_id: channel.id, thread_id: nil })
    end
  end

  describe ".start!" do
    it "creates no thread and posts no message" do
      expect { described_class.start!(room, user) }.not_to change { ::Chat::Thread.count }
      expect(channel.chat_messages.count).to eq(0)
      expect(described_class.state(room)[:thread_id]).to be_nil
    end

    it "follows the caller on the channel so chat's own endpoints accept their posts" do
      described_class.start!(room, user)

      membership = channel.membership_for(user)
      expect(membership).to be_present
      expect(membership.following).to eq(true)
    end

    it "re-follows a caller who had unfollowed the channel" do
      described_class.start!(room, user)
      ::Chat::ChannelMembershipManager.new(channel).unfollow(user)

      described_class.start!(room, user)
      expect(channel.membership_for(user).following).to eq(true)
    end

    it "broadcasts nothing" do
      published = []
      allow(MessageBus).to receive(:publish) { |ch, data, opts| published << [ch, data, opts] }

      described_class.start!(room, user)

      expect(published.select { |ch, _, _| ch == Voice.room_chat_channel(room.id) }).to be_empty
    end
  end

  describe ".post_message!" do
    it "opens a thread rooted on the first message, prefixed with a room hashtag linking back" do
      state = described_class.post_message!(room, user, "hello everyone")

      thread = live_thread(state)
      expect(thread.channel_id).to eq(channel.id)
      expect(thread.title).to eq("Voice chat in #{room.name}")
      expect(thread.original_message.message).to eq("In ##{room.slug}::room - hello everyone")
      expect(thread.original_message.cooked).to include("/voice/r/#{room.slug}")
      expect(thread.original_message.user_id).to eq(user.id)
      expect(thread.custom_fields[Voice::THREAD_ROOM_ID_FIELD]).to eq(room.id.to_s)
    end

    it "inserts a first message containing interpolation tokens literally" do
      state = described_class.post_message!(room, user, "see %{room} and \\1")

      expect(live_thread(state).original_message.message).to eq(
        "In ##{room.slug}::room - see %{room} and \\1",
      )
    end

    it "inserts a room name containing replacement escapes literally into the title" do
      room.update!(name: "Studio \\& \\1")

      thread = live_thread(described_class.post_message!(room, user, "hello everyone"))
      expect(thread.title).to eq("Voice chat in Studio \\& \\1")
    end

    it "delivers to the live thread instead of spawning a competing one" do
      first = described_class.post_message!(room, user, "first")

      # A second panel that raced the broadcast still believed no thread
      # existed — its message must land in the session thread as a reply.
      second = described_class.post_message!(room, other, "second")

      expect(second[:thread_id]).to eq(first[:thread_id])
      thread = live_thread(second)
      expect(thread.replies.last.message).to eq("second")
      expect(thread.replies.last.user_id).to eq(other.id)
    end

    it "broadcasts only when a thread is actually opened" do
      published = []
      allow(MessageBus).to receive(:publish) { |ch, data, opts| published << [ch, data, opts] }

      described_class.post_message!(room, user, "first")
      described_class.post_message!(room, other, "second")

      chat_events = published.select { |ch, _, _| ch == Voice.room_chat_channel(room.id) }
      expect(chat_events.size).to eq(1)
    end

    # publish_state's audience is the room's (anyone who can see the voice
    # room), which can be broader than who's authorized for the linked chat
    # channel — so the payload itself must never carry message content or
    # thread/channel identifiers. Clients re-fetch through the guarded
    # chat_session endpoint instead, which re-checks channel access per user.
    it "never publishes message content or thread/channel identifiers" do
      published = []
      allow(MessageBus).to receive(:publish) { |ch, data, opts| published << [ch, data, opts] }

      described_class.post_message!(room, user, "sensitive content")

      chat_events = published.select { |ch, _, _| ch == Voice.room_chat_channel(room.id) }
      expect(chat_events).to be_present
      chat_events.each { |_, data, _| expect(data).to eq({ type: "updated" }) }
    end

    it "rolls over to a fresh thread after the session goes idle and empty" do
      first = described_class.post_message!(room, user, "first")

      # No messages and no heartbeats for longer than the room's timeout: the
      # session has gone idle and empty.
      freeze_time(31.minutes.from_now) do
        rolled = described_class.post_message!(room, other, "later")
        expect(rolled[:thread_id]).to be_present
        expect(rolled[:thread_id]).not_to eq(first[:thread_id])
      end
    end

    it "keeps the session alive while its thread has recent messages" do
      first = described_class.post_message!(room, user, "first")

      # Later messages flow through chat's own API; liveness must still follow
      # them even though Voice never sees the posts.
      freeze_time(20.minutes.from_now) { post_reply!(first[:thread_id], user, "still chatting") }

      freeze_time(30.minutes.from_now) do
        expect(described_class.post_message!(room, other, "me too")[:thread_id]).to eq(
          first[:thread_id],
        )
      end
    end

    it "keeps the session alive while participants are present (heartbeat)" do
      first = described_class.post_message!(room, user, "first")

      # A heartbeat within the timeout keeps the session warm...
      freeze_time(10.minutes.from_now) { described_class.touch!(room) }

      # ...so a message a bit later still lands in the same thread.
      freeze_time(20.minutes.from_now) do
        expect(described_class.post_message!(room, user, "still here")[:thread_id]).to eq(
          first[:thread_id],
        )
      end
    end

    it "does not let a late heartbeat revive an already-idle session" do
      first = described_class.post_message!(room, user, "first")

      # The session has already gone idle and empty; a heartbeat from a
      # returning joiner must not resurrect it.
      freeze_time(31.minutes.from_now) do
        described_class.touch!(room)
        expect(described_class.post_message!(room, user, "later")[:thread_id]).not_to eq(
          first[:thread_id],
        )
      end
    end

    it "abandons a thread whose original message was deleted" do
      first = described_class.post_message!(room, user, "first")
      live_thread(first).original_message.trash!(Discourse.system_user)

      expect(described_class.state(room)[:thread_id]).to be_nil

      fresh = described_class.post_message!(room, other, "again")
      expect(fresh[:thread_id]).to be_present
      expect(fresh[:thread_id]).not_to eq(first[:thread_id])
    end

    it "surfaces the chat plugin's own error when a message is rejected" do
      # The opener is prefixed with the room hashtag, so the collision needs
      # two identical replies rather than an opener and a reply.
      described_class.post_message!(room, user, "opener")
      described_class.post_message!(room, user, "dup")

      # The chat plugin blocks an identical message posted seconds apart; that
      # reason must reach the caller, not be masked as a generic access error.
      expect { described_class.post_message!(room, user, "dup") }.to raise_error(
        Voice::ChatSession::Error,
        /identical message/i,
      )
    end

    it "raises a clear error without orphaning the message when threading is off" do
      channel.update!(threading_enabled: false)
      # The room memoizes its channel per instance (a fresh load in production
      # requests); pick the flip up here explicitly.
      room.reload

      expect { described_class.post_message!(room, user, "hello") }.to raise_error(
        Voice::ChatSession::Error,
        /threading/i,
      )

      # The message must not be left behind as a loose channel message.
      expect(channel.chat_messages.count).to eq(0)
      expect(described_class.state(room)[:thread_id]).to be_nil
    end
  end

  describe ".touch!" do
    it "is a no-op when there is no live session" do
      described_class.touch!(room)
      expect(Discourse.redis.get("voice:room:#{room.id}:chat_seen_at")).to be_nil
    end

    it "refreshes the session key TTL so a long quiet session isn't dropped" do
      described_class.post_message!(room, user, "hello")
      thread_key = "voice:room:#{room.id}:chat_thread"

      Discourse.redis.expire(thread_key, 60)
      described_class.touch!(room)

      expect(Discourse.redis.ttl(thread_key)).to be > 60
    end
  end
end
