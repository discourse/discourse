# frozen_string_literal: true

module Voice
  class AgentManager
    SESSION_TTL = 15.minutes
    PROVIDER_ROOMS_KEY = "voice:agent:provider_rooms"

    class AuthorizationError < StandardError
    end

    class << self
      def authorize!(room:)
        bot = AgentBot.user
        unless Voice.enabled? && AgentBot.available? && room.public? &&
                 ParticipantTracker.pinned_transport(room.id) == "livekit" &&
                 ParticipantTracker.human_user_ids(room.id).any?
          raise AuthorizationError
        end
        bot
      end

      def authorize_session!(room:, agent_name:)
        bot = authorize!(room:)
        Discourse.redis.sadd(PROVIDER_ROOMS_KEY, room.id)
        session_id = SecureRandom.hex(16)
        payload = { bot_user_id: bot.id, session_id:, agent_name: }
        Discourse.redis.setex(session_key(room.id, bot.id), SESSION_TTL.to_i, payload.to_json)
        session_id
      end

      def authorized_session(room:, user_id:, metadata:)
        raw = Discourse.redis.get(session_key(room.id, user_id))
        return if raw.blank?
        session = JSON.parse(raw, symbolize_names: true)
        return unless metadata == session[:session_id]
        bot = authorize!(room:)
        return unless bot.id == user_id && session[:bot_user_id] == bot.id

        session.merge(bot:, proof: raw)
      rescue JSON::ParserError, AuthorizationError
        nil
      end

      def revoke_session(room_id, user_id)
        ParticipantTracker.revoke_agent(
          room_id,
          user_id,
          session_key: session_key(room_id, user_id),
        )
        AgentDispatcher.cancel(room_id, user_id)
      end

      def evict!(room:, user_id:)
        dispatched = AgentDispatcher.pending?(room.id)
        identity = ParticipantTracker.get_metadata(room.id, user_id)[:livekit_identity]
        revoke_session(room.id, user_id)
        ParticipantTracker.mark_left(room.id, user_id)
        ParticipantTracker.remove(room.id, user_id)
        unless dispatched
          Livekit::RoomServiceClient.remove_participant(
            room,
            user_id,
            **(identity ? { identity: } : {}),
          )
        end
      end

      def stop_all!
        Room
          .where(id: provider_room_ids)
          .find_each do |room|
            revoke_room_sessions(room)
            AgentDispatcher.cancel(room.id)
            RoomBroadcaster.publish_participants(room)
          end
      end

      def evict_agents_in_room!(room, delete_room: true)
        agent_user_ids = ParticipantTracker.agent_user_ids(room.id)
        revoke_room_sessions(room)
        AgentDispatcher.cancel(room.id)
        agent_user_ids.each { |user_id| evict!(room:, user_id:) }
        AgentDispatcher.sessions(room) if AgentDispatcher.pending?(room.id)
        room_deleted = !delete_room || Livekit::RoomServiceClient.delete_room(room)
        if room_deleted && !AgentDispatcher.pending?(room.id)
          Discourse.redis.srem(PROVIDER_ROOMS_KEY, room.id)
        end
        ParticipantTracker.clear_transport_pin(room.id)
      end

      def provider_room_ids
        Discourse.redis.smembers(PROVIDER_ROOMS_KEY).map(&:to_i)
      end

      def provider_room?(room_id)
        Discourse.redis.sismember(PROVIDER_ROOMS_KEY, room_id)
      end

      def reconcile(room)
        return unless provider_room?(room.id) || ParticipantTracker.agent_user_ids(room.id).any?
        return evict_agents_in_room!(room) if ParticipantTracker.human_user_ids(room.id).empty?

        sessions = AgentDispatcher.sessions(room)
        participants = Livekit::RoomServiceClient.list_participants(Livekit.room_name(room))
        return unless participants[:ok]

        live_agents = Set.new
        Array(participants.dig(:data, "participants")).each do |participant|
          identity = participant["identity"].to_s
          session = sessions[identity]
          next unless session
          next if [4, "AGENT"].exclude?(participant["kind"])

          bot = session[:bot]
          next unless Livekit::RoomServiceClient.update_participant(room, bot, identity:)
          metadata = {
            external_agent: true,
            livekit_identity: identity,
            role: "speaker",
            last_heartbeat_at: Time.now.to_f,
          }
          unless ParticipantTracker.commit_agent(
                   room.id,
                   bot.id,
                   session_key: session_key(room.id, bot.id),
                   proof: session[:proof],
                   ttl: SESSION_TTL.to_i,
                   metadata:,
                   sid: participant["sid"],
                 )
            Livekit::RoomServiceClient.remove_participant(room, bot.id, identity:)
            next
          end
          live_agents << bot.id
        end

        ParticipantTracker
          .agent_user_ids(room.id)
          .each do |user_id|
            ParticipantTracker.expire_presence(room.id, user_id) if live_agents.exclude?(user_id)
          end
        RoomBroadcaster.publish_participants_if_changed(room)
      end

      private

      def revoke_room_sessions(room)
        Discourse
          .redis
          .scan_each(match: "voice:agent:session:#{room.id}:*") do |key|
            revoke_session(room.id, key.split(":").last.to_i)
          end
      end

      def session_key(room_id, user_id)
        "voice:agent:session:#{room_id}:#{user_id}"
      end
    end
  end
end
