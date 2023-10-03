# frozen_string_literal: true

module Jobs
  module Chat
    class AutoJoinUsers < ::Jobs::Scheduled
      every 1.hour

      def execute(_args)
        return if !SiteSetting.chat_enabled

        ::Chat::Channel
          .where(auto_join_users: true)
          .each do |channel|
            ::Chat::ChannelMembershipManager.new(channel).enforce_automatic_channel_memberships
          end
      end
    end
  end
end
