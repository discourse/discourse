# frozen_string_literal: true

module Jobs
  module Chat
    class ChannelArchive < ::Jobs::Base
      sidekiq_options retry: false

      def execute(args = {})
        channel_archive = ::Chat::ChannelArchive.find_by(id: args[:chat_channel_archive_id])

        # this should not really happen, but better to do this than throw an error
        if channel_archive.blank?
          ::Rails.logger.warn(
            "Chat channel archive #{args[:chat_channel_archive_id]} could not be found, aborting archive job.",
          )
          return
        end

        if channel_archive.complete?
          channel_archive.chat_channel.update!(status: :archived)

          ::Chat::Publisher.publish_archive_status(
            channel_archive.chat_channel,
            archive_status: :success,
            archived_messages: channel_archive.archived_messages,
            archive_topic_id: channel_archive.destination_topic_id,
            total_messages: channel_archive.total_messages,
          )

          return
        end

        ::DistributedMutex.synchronize(
          "archive_chat_channel_#{channel_archive.chat_channel_id}",
          validity: 20.minutes,
        ) { ::Chat::ChannelArchiveService.new(channel_archive).execute }
      end
    end
  end
end
