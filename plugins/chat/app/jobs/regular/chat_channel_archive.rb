# frozen_string_literal: true

module Jobs
  class ChatChannelArchive < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args = {})
      channel_archive = ::ChatChannelArchive.find_by(id: args[:chat_channel_archive_id])

      # this should not really happen, but better to do this than throw an error
      if channel_archive.blank?
        Rails.logger.warn(
          "Chat channel archive #{args[:chat_channel_archive_id]} could not be found, aborting archive job.",
        )
        return
      end

      return if channel_archive.complete?

      DistributedMutex.synchronize(
        "archive_chat_channel_#{channel_archive.chat_channel_id}",
        validity: 20.minutes,
      ) { Chat::ChatChannelArchiveService.new(channel_archive).execute }
    end
  end
end
