# frozen_string_literal: true

module Jobs
  module Voice
    class CleanupEphemeralRooms < ::Jobs::Scheduled
      every 5.minutes

      def execute(_args)
        return unless SiteSetting.voice_enabled

        ::Voice::EphemeralRoomManager.cleanup!
      end
    end
  end
end
