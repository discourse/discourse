# frozen_string_literal: true

module Jobs
  class UpdateChannelUserCount < Jobs::Base
    def execute(args = {})
      channel = ChatChannel.find_by(id: args[:chat_channel_id])
      return if channel.blank?
      return if !channel.user_count_stale

      channel.update!(
        user_count: ChatChannelMembershipsQuery.count(channel: channel),
        user_count_stale: false,
      )

      ChatPublisher.publish_chat_channel_metadata(channel)
    end
  end
end
