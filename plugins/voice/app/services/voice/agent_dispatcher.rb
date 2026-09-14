# frozen_string_literal: true

module Voice
  class AgentDispatcher
    class DispatchError < StandardError
    end

    def self.dispatch!(room:, agent_name:)
      unless agent_name.is_a?(String) && agent_name.strip.present? && agent_name.length <= 256
        raise Discourse::InvalidParameters.new(:agent_name)
      end
      agent_name = agent_name.strip
      DistributedMutex.synchronize("voice:dispatch:#{room.id}") do
        bot = AgentManager.authorize!(room:)
        AgentManager.revoke_session(room.id, bot.id)
        session_id = AgentManager.authorize_session!(room:, agent_name:)
        record = {
          "bot_user_id" => bot.id,
          "session_id" => session_id,
          "agent_name" => agent_name,
          "metadata" => { voice_session_id: session_id }.to_json,
          "created_at" => Time.now.to_i,
        }
        save(room.id, record)

        result =
          Livekit::AgentDispatchClient.create(room, agent_name:, metadata: record["metadata"])
        if result[:ok] && result.dig(:data, "id").present?
          record["dispatch_id"] = result[:data]["id"]
          save(room.id, record)
        else
          AgentManager.revoke_session(room.id, bot.id)
          raise DispatchError
        end

        unless authorized_session(room, record)
          cancel(room.id, bot.id)
          raise AgentManager::AuthorizationError
        end
        record["dispatch_id"]
      end
    end

    # Keep cleanup records separate from admission proofs so revocation still
    # takes effect when the provider is unavailable, and deletion can be retried.
    def self.cancel(room_id, user_id = nil)
      room = Room.find_by(id: room_id)
      return unless room

      records(room_id).each do |record|
        next if user_id && record["bot_user_id"] != user_id
        record["revoked"] = true
        save(room_id, record)
        delete_dispatch(room, record) if record["dispatch_id"]
      end
    end

    def self.pending?(room_id)
      Discourse.redis.hlen(key(room_id)).positive?
    end

    def self.sessions(room)
      pending = records(room.id)
      return {} if pending.empty?

      result = Livekit::AgentDispatchClient.list(room)
      return {} unless result[:ok]

      dispatches = result[:data]["agentDispatches"] || result[:data]["agent_dispatches"] || []
      pending.each_with_object({}) do |record, sessions|
        dispatch =
          dispatches.find do |candidate|
            candidate["room"] == Livekit.room_name(room) &&
              (candidate["agentName"] || candidate["agent_name"]) == record["agent_name"] &&
              candidate["metadata"] == record["metadata"] &&
              (!record["dispatch_id"] || candidate["id"] == record["dispatch_id"])
          end
        unless dispatch
          # A timed-out create may still complete remotely. Retain its nonce
          # while the request settles so a later sweep can find and delete it.
          if record["created_at"] < 2.minutes.ago.to_i
            Discourse.redis.hdel(key(room.id), record["session_id"])
          end
          next
        end

        record["dispatch_id"] = dispatch["id"]
        identities =
          Array(dispatch.dig("state", "jobs")).filter_map do |job|
            state = job["state"] || {}
            identity = state["participantIdentity"] || state["participant_identity"]
            next if [1, "JS_RUNNING"].exclude?(state["status"])
            next unless (job["dispatchId"] || job["dispatch_id"]) == dispatch["id"]
            next if identity.blank? || /\A-?\d+\z/.match?(identity)

            identity
          end
        record["participant_identity"] = identities.first if identities.one?
        save(room.id, record)
        session = record["revoked"] ? nil : authorized_session(room, record)
        unless session
          delete_dispatch(room, record)
          next
        end

        sessions[identities.first] = session if identities.one?
      end
    end

    def self.authorized_session(room, record)
      AgentManager.authorized_session(
        room:,
        user_id: record["bot_user_id"],
        metadata: record["session_id"],
      )
    end
    private_class_method :authorized_session

    def self.delete_dispatch(room, record)
      if Livekit::AgentDispatchClient.delete(room, record["dispatch_id"])[:ok]
        Discourse.redis.hdel(key(room.id), record["session_id"])
      elsif record["participant_identity"]
        Livekit::RoomServiceClient.remove_participant(
          room,
          record["bot_user_id"],
          identity: record["participant_identity"],
        )
      end
    end
    private_class_method :delete_dispatch

    def self.records(room_id)
      Discourse.redis.hvals(key(room_id)).map { |raw| JSON.parse(raw) }
    end
    private_class_method :records

    def self.save(room_id, record)
      Discourse.redis.hset(key(room_id), record["session_id"], record.to_json)
      Discourse.redis.sadd(AgentManager::PROVIDER_ROOMS_KEY, room_id)
    end
    private_class_method :save

    def self.key(room_id)
      "voice:agent:dispatches:#{room_id}"
    end
    private_class_method :key
  end
end
