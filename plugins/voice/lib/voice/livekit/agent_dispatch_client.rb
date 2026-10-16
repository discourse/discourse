# frozen_string_literal: true

module Voice
  module Livekit
    class AgentDispatchClient
      def self.create(room, agent_name:, metadata:)
        request(room, "CreateDispatch", agent_name:, metadata:)
      end

      def self.list(room)
        request(room, "ListDispatch")
      end

      def self.delete(room, dispatch_id)
        request(room, "DeleteDispatch", dispatch_id:)
      end

      def self.request(room, method, **body)
        return { ok: false } unless Livekit.configured?

        name = Livekit.room_name(room)
        response =
          Twirp.post(
            service: "AgentDispatchService",
            method:,
            body: body.merge(room: name),
            grants: {
              roomAdmin: true,
              room: name,
            },
            timeout: 5,
          )
        return { ok: true, data: {} } if method == "DeleteDispatch" && response.status == 404
        return { ok: true, data: JSON.parse(response.body) } if response.status == 200

        Rails.logger.warn("[voice-livekit] #{method} failed: HTTP #{response.status}")
        { ok: false }
      rescue StandardError => error
        Rails.logger.warn("[voice-livekit] #{method} failed: #{error.class}")
        { ok: false }
      end
      private_class_method :request
    end
  end
end
