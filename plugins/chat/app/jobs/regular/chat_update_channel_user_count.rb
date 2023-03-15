# frozen_string_literal: true

module Jobs
  class ChatUpdateChannelUserCount < Jobs::Base
    def execute(args = {})
      channel = Chat::Channel.find_by(id: args[:chat_channel_id])
      return if channel.blank?
      return if !channel.user_count_stale

      channel.update!(
        user_count: Chat::ChannelMembershipsQuery.count(channel),
        user_count_stale: false,
      )

      Chat::Publisher.publish_chat_channel_metadata(channel)
    end
  end
end
