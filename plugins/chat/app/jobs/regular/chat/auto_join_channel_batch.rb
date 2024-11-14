# frozen_string_literal: true

# TODO: delete this unused job after 2025-01-01

module Jobs
  module Chat
    class AutoJoinChannelBatch < ::Jobs::Base
      def execute(args)
        # no-op
      end
    end
  end
end
