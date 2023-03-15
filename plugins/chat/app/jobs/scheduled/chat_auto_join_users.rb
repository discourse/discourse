# frozen_string_literal: true

module Jobs
  class ChatAutoJoinUsers < ::Jobs::Scheduled
    every 1.hour

    def execute(_args)
      Chat::Channel
        .where(auto_join_users: true)
        .each do |channel|
          Chat::ChannelMembershipManager.new(channel).enforce_automatic_channel_memberships
        end
    end
  end
end
