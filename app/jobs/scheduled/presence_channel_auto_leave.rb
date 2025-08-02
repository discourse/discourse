# frozen_string_literal: true

module Jobs
  class PresenceChannelAutoLeave < ::Jobs::Scheduled
    every PresenceChannel::DEFAULT_TIMEOUT.seconds

    def execute(args)
      PresenceChannel.auto_leave_all
    end
  end
end
