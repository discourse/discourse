# frozen_string_literal: true

module Jobs
  module Chat
    class ProcessMessage < ::Jobs::Base
      def execute(args = {})
        hotlinked_media_pending = false

        ::DistributedMutex.synchronize(
          "jobs_chat_process_message_#{args[:chat_message_id]}",
          validity: 10.minutes,
        ) do
          chat_message =
            ::Chat::Message.includes(uploads: { optimized_videos: :optimized_upload }).find_by(
              id: args[:chat_message_id],
            )
          return if !chat_message

          processor =
            ::Chat::MessageProcessor.new(
              chat_message,
              { invalidate_oneboxes: args[:invalidate_oneboxes] },
            )
          processor.run!

          if processor.dirty?
            chat_message.update!(
              cooked: processor.html,
              cooked_version: ::Chat::Message::BAKED_VERSION,
            )
          end

          stale_ids = processor.stale_hotlinked_media_ids
          chat_message.hotlinked_media.where(id: stale_ids).destroy_all if stale_ids.present?
          hotlinked_media_pending = processor.hotlinked_media_pending?

          # we don't process mentions when creating/updating message so we always have to do it
          chat_message.upsert_mentions

          # extract external links for webhook-based rebaking
          ::Chat::MessageLink.extract_from(chat_message)

          unless args[:skip_notifications]
            if args[:edit_timestamp]
              ::Chat::Notifier.new(chat_message, args[:edit_timestamp]).notify_edit
            else
              ::Chat::Notifier.new(chat_message, chat_message.created_at).notify_new
            end
          end

          ::Chat::Publisher.publish_processed!(chat_message)
        end

        # outside the mutex: the pull job re-cooks through this job, and would
        # block on the lock we still hold whenever jobs run inline
        if hotlinked_media_pending && !args[:skip_pull_hotlinked_images] &&
             SiteSetting.download_remote_images_to_local? && SiteSetting.chat_allow_uploads?
          ::Jobs.enqueue(::Jobs::Chat::PullHotlinkedImages, chat_message_id: args[:chat_message_id])
        end
      end
    end
  end
end
