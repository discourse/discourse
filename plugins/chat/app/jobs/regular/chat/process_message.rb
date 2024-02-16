# frozen_string_literal: true

module Jobs
  module Chat
    class ProcessMessage < ::Jobs::Base
      def execute(args = {})
        ::DistributedMutex.synchronize(
          "jobs_chat_process_message_#{args[:chat_message_id]}",
          validity: 10.minutes,
        ) do
          chat_message = ::Chat::Message.find_by(id: args[:chat_message_id])
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

          # we dont process mentions when creating/updating message so we always have to do it
          chat_message.upsert_mentions

          is_edit = args[:edit_timestamp].present?
          if is_edit
            timestamp = args[:edit_timestamp]
          else
            timestamp = chat_message.created_at
          end
          notify_mentioned_and_watching_users(chat_message.id, is_edit, timestamp)

          ::Chat::Publisher.publish_processed!(chat_message)
        end
      end

      private

      def notify_mentioned_and_watching_users(message_id, is_edit, timestamp)
        Jobs.enqueue(
          Jobs::Chat::NotifyMentioned,
          { message_id: message_id, is_edit: is_edit, timestamp: timestamp },
        )
      end
    end
  end
end
