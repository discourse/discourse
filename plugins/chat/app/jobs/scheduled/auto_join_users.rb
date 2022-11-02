# frozen_string_literal: true

module Jobs
  class AutoJoinUsers < ::Jobs::Scheduled
    every 1.hour

    def execute(_args)
      ChatChannel
        .where(auto_join_users: true)
        .each do |channel|
          Chat::ChatChannelMembershipManager.new(channel).enforce_automatic_channel_memberships
        end
    end
  end
end
