# frozen_string_literal: true

module Jobs
  module Chat
    class MarkAllChannelThreadsRead < Jobs::Base
      sidekiq_options queue: "critical"

      def execute(args = {})
        channel = ::Chat::Channel.find_by(id: args[:channel_id])
        return if channel.blank?
        channel.mark_all_threads_as_read
      end
    end
  end
end
