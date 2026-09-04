# frozen_string_literal: true

module Voice
  # Bridges a voice room to the Discourse chat plugin.
  #
  # A room is linked to a chat channel; each "chat session" lives in a thread on
  # that channel. A session's thread is only created when someone actually sends
  # a message: that first message roots the thread, prefixed with the room's
  # hashtag so the opener links back to the room, and the thread is titled
  # after the room.
  #
  # From then on participants read and post through chat's own UI and API;
  # Voice only tracks WHICH thread is the room's live session.
  #
  # The live thread id lives in Redis, keyed by room. Liveness is derived from
  # two sources: the timestamp of the thread's most recent chat message
  # (messages already carry their own +created_at+, so there's nothing extra to
  # store) and a Redis "last seen" timestamp bumped on the room heartbeat while
  # a participant is present. A session only rolls over to a fresh thread once
  # both have been quiet longer than the room's configured timeout — i.e. it
  # has been idle (no messages) AND empty (no one present).
  class ChatSession
    # Raised when an underlying chat operation is rejected for a reason worth
    # showing the user (threading disabled on the channel, a duplicate or
    # too-long message, etc.) rather than masking it behind a generic "not
    # permitted" error. The controller renders it as a 422 carrying the real
    # message.
    class Error < StandardError
    end

    KEY_NAMESPACE = "voice:room"
    SAFETY_TTL = 1.day.to_i

    class << self
      def chat_available?
        defined?(::Chat) && SiteSetting.voice_chat_enabled && SiteSetting.chat_enabled
      end

      # Whether the current user can use chat in this room (chat installed +
      # enabled, a channel is linked, and the user may post in that channel).
      def available_for?(room, guardian)
        return false unless chat_available?
        channel = room.chat_channel
        return false unless channel
        guardian.can_chat? && guardian.can_join_chat_channel?(channel)
      end

      def available_for_rooms(rooms, guardian)
        availability = rooms.to_h { |room| [room.id, false] }
        return availability unless chat_available?
        return availability if guardian.anonymous? || !guardian.can_chat?

        channel_ids = rooms.filter_map(&:chat_channel_id).uniq
        return availability if channel_ids.empty?

        channels = ::Chat::Channel.includes(:chatable).where(id: channel_ids).index_by(&:id)
        direct_messages =
          channels.values.filter_map do |channel|
            channel.chatable if channel.direct_message_channel?
          end
        if direct_messages.present?
          ActiveRecord::Associations::Preloader.new(
            records: direct_messages,
            associations: :users,
          ).call
        end

        category_ids =
          channels.values.filter_map { |channel| channel.chatable_id if channel.category_channel? }
        post_allowed_category_ids =
          if !guardian.is_anonymous? && category_ids.present?
            Category.post_create_allowed(guardian).where(id: category_ids).pluck(:id)
          end

        rooms.each do |room|
          channel = channels[room.chat_channel_id]
          room.preload_chat_channel(channel)
          next unless channel

          availability[room.id] = if post_allowed_category_ids
            guardian.can_join_chat_channel?(
              channel,
              post_allowed_category_ids: post_allowed_category_ids,
            )
          else
            guardian.can_join_chat_channel?(channel)
          end
        end

        availability
      end

      # A snapshot of the room's live chat session for the client: the linked
      # channel and the active thread (if any). Never creates anything.
      def state(room)
        channel_id = room.chat_channel_id
        thread_id = channel_id.present? && !stale?(room) ? live_thread_id(room) : nil
        { channel_id: channel_id, thread_id: thread_id }
      end

      # Records that a participant is present (called on the room heartbeat) so a
      # session with people in it but no recent messages doesn't roll over.
      # Message recency is read straight from the messages themselves.
      def touch!(room)
        return if redis.get(thread_key(room.id)).blank?

        # Never revive a session that already went idle AND empty — let the next
        # panel open roll it over to a fresh thread instead.
        return if stale?(room)

        # Keep the identity key alive alongside presence, so a long, present but
        # quiet session doesn't lose its thread pointer to TTL expiry.
        redis.expire(thread_key(room.id), SAFETY_TTL)
        redis.set(seen_key(room.id), Time.now.to_f, ex: SAFETY_TTL)
      end

      # Prepares the room's session for +user+ without creating anything: rolls
      # a stale session over and follows the user on the channel so chat's own
      # message endpoints accept their posts. The thread itself only comes into
      # existence with the session's first message (see +post_message!+).
      # Returns the session state.
      def start!(room, user)
        channel = ensure_channel!(room)
        with_session_lock(room) do
          roll_over_if_stale!(room)
          ::Chat::ChannelMembershipManager.new(channel).follow(user)
        end
        state(room)
      end

      # Posts the session's opening message as +user+: the message is created on
      # the channel and a thread is opened from it. Once a thread is live, messages flow through
      # chat's own API instead — this is only called by a panel that believes no
      # thread exists yet, so if one appeared in the meantime the message is
      # delivered there rather than spawning a competing thread.
      # Returns the session state.
      def post_message!(room, user, message)
        channel = ensure_channel!(room)
        with_session_lock(room) do
          roll_over_if_stale!(room)

          if (thread_id = live_thread_id(room))
            create_message!(
              guardian: user.guardian,
              channel_id: channel.id,
              message: message,
              thread_id: thread_id,
            )
          else
            open_session_thread!(room, channel, user, message)
          end
        end
        state(room)
      end

      def clear(room_id)
        redis.del(thread_key(room_id))
        redis.del(seen_key(room_id))
      end

      private

      def ensure_channel!(room)
        room.chat_channel ||
          raise(
            Discourse::InvalidAccess.new(
              :voice_chat_unavailable,
              nil,
              custom_message: "voice.errors.chat_unavailable",
            ),
          )
      end

      def roll_over_if_stale!(room)
        clear(room.id) if stale?(room)
      end

      # Serializes the read-modify-write of a room's session so two near
      # simultaneous panel opens can't each start their own thread.
      def with_session_lock(room, &blk)
        DistributedMutex.synchronize("#{KEY_NAMESPACE}:#{room.id}:chat_lock", &blk)
      end

      # Opens the session's thread from its first message: +message+ itself
      # roots the thread, prefixed with the room's hashtag so the opener links
      # back to the room. The change is published so every open panel picks
      # the new thread up.
      def open_session_thread!(room, channel, user, message)
        # Bail before posting: if the channel can't hold a thread, thread
        # creation would be rejected and leave the message orphaned as a loose
        # channel message (re-posted on every retry).
        ensure_threading_enabled!(channel)

        root =
          create_message!(
            guardian: user.guardian,
            channel_id: channel.id,
            message: opener_for(room, message),
          )
        thread = open_thread!(channel, root, title: title_for(room))
        # Mark the thread as this room's before anything is published: a panel
        # reacting to the publish looks the thread up by this field right away,
        # and a miss would be cached as "not a session thread". Unlike the
        # Redis pointer, the marker outlives the session, tracing any past
        # session thread back to its room.
        thread.upsert_custom_fields(Voice::THREAD_ROOM_ID_FIELD => room.id)
        store_thread(room, thread.id)
        publish_state(room)

        thread
      end

      # --- chat plumbing -------------------------------------------------------

      def open_thread!(channel, original_message, title:)
        params = {
          channel_id: channel.id,
          original_message_id: original_message.id,
          title: title.truncate(::Chat::Thread::MAX_TITLE_LENGTH),
        }

        result = ::Chat::CreateThread.call(guardian: Discourse.system_user.guardian, params: params)
        raise_unless_chat_success(result)
        result.thread
      end

      def create_message!(guardian:, channel_id:, message:, thread_id: nil)
        result =
          ::Chat::CreateMessage.call(
            guardian: guardian,
            params: { chat_channel_id: channel_id, thread_id: thread_id, message: message }.compact,
            options: {
              enforce_membership: true,
            },
          )
        raise_unless_chat_success(result)
        result.message_instance
      end

      def ensure_threading_enabled!(channel)
        return if channel.threading_enabled?
        raise Error, I18n.t("voice.errors.chat_threading_disabled")
      end

      def raise_unless_chat_success(result)
        return if result.success?
        Rails.logger.warn(
          "[voice] chat operation failed: #{Service::StepsInspector.new(result).inspect}",
        )
        raise Error, chat_failure_message(result)
      end

      # Best-effort, user-facing reason a chat service failed — the validation
      # error on the rejected message/thread, else the failing policy's reason,
      # else a generic fallback. Used verbatim in the 422 the controller
      # returns.
      def chat_failure_message(result)
        record = result.message_instance || result.thread
        if record.respond_to?(:errors) && record.errors.present?
          return record.errors.full_messages.to_sentence
        end
        Service::StepsInspector.new(result).error.presence ||
          I18n.t("voice.errors.chat_unavailable")
      end

      # Publishes a content-free "something changed" signal, not the state
      # itself: `room.message_bus_targets` is the room's audience, which can be
      # broader than who is actually authorized to see the linked chat channel
      # (e.g. a public room linked to a restricted channel). Clients react by
      # re-fetching through the chat_session endpoint, which re-checks
      # `available_for?` for the requesting user on every call.
      def publish_state(room)
        MessageBus.publish(
          Voice.room_chat_channel(room.id),
          { type: "updated" },
          **message_bus_targets(room),
        )
      end

      # Same audience the room broadcaster uses: the room's configured targets
      # plus anyone currently present, so a participant who isn't a channel/room
      # member still sees the panel follow along.
      def message_bus_targets(room)
        targets = room.message_bus_targets
        participant_ids = Voice::ParticipantTracker.user_ids(room.id)
        return targets if participant_ids.empty?
        targets.merge(user_ids: Array(targets[:user_ids] || []) | participant_ids)
      end

      # --- redis state ---------------------------------------------------------

      def live_thread_id(room)
        id = redis.get(thread_key(room.id)).to_i
        return nil if id <= 0
        thread = ::Chat::Thread.find_by(id: id, channel_id: room.chat_channel_id)
        return nil unless thread
        # If the thread's original message has been deleted the thread can no
        # longer be loaded by participants, so treat the session as gone and let
        # the next panel open start a fresh one. (Chat::Message is soft-deleted,
        # so this existence check excludes trashed rows.)
        unless ::Chat::Message.exists?(
                 id: thread.original_message_id,
                 chat_channel_id: room.chat_channel_id,
               )
          return nil
        end
        id
      end

      def store_thread(room, thread_id)
        redis.set(thread_key(room.id), thread_id, ex: SAFETY_TTL)
      end

      # A session is stale once it has been both idle (no messages) and empty (no
      # one present, so no heartbeats) for longer than the room's timeout.
      def stale?(room)
        last = liveness_at(room)
        return true if last.nil?
        (Time.now.to_f - last) > room.chat_idle_seconds
      end

      # The most recent sign of life: the newest message in the session, or the
      # last heartbeat while someone was present — whichever is later.
      def liveness_at(room)
        candidates = []
        message_at = last_message_at(room)
        candidates << message_at.to_f if message_at
        seen_at = redis.get(seen_key(room.id))
        candidates << seen_at.to_f if seen_at.present?
        candidates.max
      end

      # Timestamp of the session's most recent (non-deleted) chat message, read
      # straight from the thread's messages.
      def last_message_at(room)
        thread_id = redis.get(thread_key(room.id)).to_i
        return nil if thread_id <= 0
        ::Chat::Message.where(thread_id: thread_id).maximum(:created_at)
      end

      # I18n interpolation inserts the message verbatim (no re-interpolation),
      # so user text containing tokens like %{room} or gsub escapes is safe.
      def opener_for(room, message)
        I18n.t(
          "voice.chat.default_thread_opener",
          room: "##{room.slug}::#{Voice::RoomHashtagDataSource.type}",
          message: message,
        )
      end

      def title_for(room)
        I18n.t("voice.chat.default_thread_title", room: room.name.to_s).strip
      end

      def redis
        Discourse.redis
      end

      def thread_key(room_id)
        "#{KEY_NAMESPACE}:#{room_id}:chat_thread"
      end

      def seen_key(room_id)
        "#{KEY_NAMESPACE}:#{room_id}:chat_seen_at"
      end
    end
  end
end
