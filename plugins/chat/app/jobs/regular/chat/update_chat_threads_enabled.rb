# frozen_string_literal: true

module Jobs
  module Chat
    class UpdateChatThreadsEnabled < Jobs::Base
      def execute(args = {})
        has_thread_channels = ::Chat::Channel.where(threading_enabled: true).exists?
        return if SiteSetting.chat_threads_enabled === has_thread_channels

        SiteSetting.chat_threads_enabled = has_thread_channels
      end
    end
  end
end
