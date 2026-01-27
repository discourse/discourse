# frozen_string_literal: true

module Jobs
  module Chat
    class ProcessMessage < ::Jobs::Base
      def execute(args = {})
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
      end
    end
  end
end
