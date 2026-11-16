# frozen_string_literal: true

module Jobs
  module Live
    class CleanupEphemeralRooms < ::Jobs::Scheduled
      every 5.minutes

      def execute(_args)
        return unless SiteSetting.live_enabled

        ::Live::EphemeralRoomManager.cleanup!
      end
    end
  end
end
