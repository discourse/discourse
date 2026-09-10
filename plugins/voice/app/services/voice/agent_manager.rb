# frozen_string_literal: true

module Voice
  class AgentManager
    SESSION_TTL = 15.minutes

    class AuthorizationError < StandardError
    end

    class << self
      def create_credential!(integration)
        credential = SecureRandom.urlsafe_base64(32)
        integration.update!(credential_digest: digest(credential))
        credential
      end

      def authenticate(credential)
        return if credential.blank?

        AgentIntegration.find_by(credential_digest: digest(credential))
      end

      def authorize!(integration:, room:)
        raise AuthorizationError unless integration&.active?
        raise AuthorizationError unless Voice.enabled?
        raise AuthorizationError unless eligible_bot?(integration.bot_user)
        raise AuthorizationError unless integration.rooms.exists?(id: room.id)
        raise AuthorizationError unless Livekit.configured?
        raise AuthorizationError unless ParticipantTracker.pinned_transport(room.id) == "livekit"
        raise AuthorizationError if ParticipantTracker.human_user_ids(room.id).none?
        raise AuthorizationError if integration.excluded_from?(room)

        integration
      end

      def authorize_session!(integration:, room:)
        session_id = SecureRandom.hex(16)
        payload = {
          integration_id: integration.id,
          session_id: session_id,
          role: role_for(integration, room),
        }
        Discourse.redis.setex(
          session_key(room.id, integration.bot_user_id),
          SESSION_TTL.to_i,
          payload.to_json,
        )
        session_id
      end

      def role_for(integration, room)
        membership = room.room_memberships.find_by(user_id: integration.bot_user_id)
        return "participant" if membership&.participant?
        return "speaker" if integration.role_name == "speaker"

        "participant"
      end

      def authorized_session?(room:, user_id:, metadata:)
        !!authorized_session(room:, user_id:, metadata:)
      rescue JSON::ParserError, AuthorizationError
        false
      end

      def authorized_session(room:, user_id:, metadata:)
        return unless user_id.to_s.match?(/\A-\d+\z/)
        raw = Discourse.redis.get(session_key(room.id, user_id))
        return if raw.blank?

        session = JSON.parse(raw, symbolize_names: true)
        return unless metadata.to_s == session[:session_id]

        integration = AgentIntegration.find_by(id: session[:integration_id])
        authorize!(integration:, room:)
        return unless integration.bot_user_id == user_id.to_i

        session.merge(integration: integration)
      rescue JSON::ParserError, AuthorizationError
        nil
      end

      def revoke_session(room_id, user_id)
        Discourse.redis.del(session_key(room_id, user_id))
      end

      def revoke_sessions!(integration)
        Discourse
          .redis
          .scan_each(match: "voice:agent:session:*:#{integration.bot_user_id}") do |key|
            Discourse.redis.del(key)
          end
      end

      def exclude!(room:, user_id:, duration: nil)
        valid_duration =
          duration.nil? || (/\A\d+\z/.match?(duration.to_s) && duration.to_i <= 365.days.to_i)
        raise Discourse::InvalidParameters.new(:duration) unless valid_duration
        integration = AgentIntegration.find_by(bot_user_id: user_id)
        return unless integration

        expires_at = duration.to_i.positive? ? duration.to_i.seconds.from_now : nil
        exclusion = integration.exclusions.find_or_initialize_by(room_id: room.id)
        exclusion.expires_at = expires_at
        exclusion.save!
        revoke_session(room.id, user_id)
        integration
      end

      def evict!(room:, user_id:)
        revoke_session(room.id, user_id)
        ParticipantTracker.mark_left(room.id, user_id)
        ParticipantTracker.remove(room.id, user_id)
        Livekit::RoomServiceClient.remove_participant(room, user_id)
      end

      def evict_integration!(integration)
        revoke_sessions!(integration)
        ParticipantTracker.recently_active_room_ids.each do |room_id|
          room = Room.find_by(id: room_id)
          next unless room
          if ParticipantTracker.user_ids(room.id).include?(integration.bot_user_id)
            evict!(room:, user_id: integration.bot_user_id)
            RoomBroadcaster.publish_participants(room)
          end
        end
      end

      def evict_agents_in_room!(room, delete_room: true)
        Discourse
          .redis
          .scan_each(match: "voice:agent:session:#{room.id}:*") { |key| Discourse.redis.del(key) }
        ParticipantTracker.agent_user_ids(room.id).each { |user_id| evict!(room:, user_id:) }
        Livekit::RoomServiceClient.delete_room(room) if delete_room
        ParticipantTracker.clear_transport_pin(room.id)
      end

      def reconcile(room)
        return unless ParticipantTracker.pinned_transport(room.id) == "livekit"
        return unless AgentIntegration.exists? || ParticipantTracker.agent_user_ids(room.id).any?
        return evict_agents_in_room!(room) if ParticipantTracker.human_user_ids(room.id).empty?

        participants = Livekit::RoomServiceClient.list_participants(Livekit.room_name(room))
        return unless participants[:ok]

        live_agents = Set.new
        Array(participants.dig(:data, "participants")).each do |participant|
          identity = participant["identity"].to_s
          next unless /\A-[1-9]\d*\z/.match?(identity)

          user_id = identity.to_i
          session = authorized_session(room:, user_id:, metadata: participant["metadata"])
          unless session
            Livekit::RoomServiceClient.remove_participant(room, user_id)
            next
          end

          live_agents << user_id
          Discourse.redis.expire(session_key(room.id, user_id), SESSION_TTL.to_i)
          ParticipantTracker.add(room.id, user_id)
          ParticipantTracker.set_livekit_sid(room.id, user_id, participant["sid"])
          metadata = ParticipantTracker.get_metadata(room.id, user_id)
          metadata.merge!(
            external_agent: true,
            agent_can_speak: session[:integration].role_name == "speaker",
            role: role_for(session[:integration], room),
            last_heartbeat_at: Time.now.to_f,
          )
          ParticipantTracker.update_metadata(room.id, user_id, metadata)
          can_publish = role_for(session[:integration], room) == "speaker"
          permission = participant["permission"] || {}
          if (permission["canPublish"] || permission["can_publish"] || false) != can_publish
            Livekit::RoomServiceClient.update_participant(room, session[:integration].bot_user)
          end
        end

        ParticipantTracker
          .agent_user_ids(room.id)
          .each do |user_id|
            next if live_agents.include?(user_id)
            ParticipantTracker.expire_presence(room.id, user_id)
          end
        RoomBroadcaster.publish_participants_if_changed(room)
      end

      private

      def digest(credential)
        Digest::SHA256.hexdigest(credential.to_s)
      end

      def session_key(room_id, user_id)
        "voice:agent:session:#{room_id}:#{user_id}"
      end

      def eligible_bot?(user)
        user&.bot? && user.id.negative? && !user.is_system_user? && user.active? && !user.suspended?
      end
    end
  end
end
