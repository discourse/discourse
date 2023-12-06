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

          # notifier should be idempotent and not re-notify
          if args[:edit_timestamp]
            ::Chat::Notifier.new(chat_message, args[:edit_timestamp]).notify_edit
          else
            ::Chat::Notifier.new(chat_message, chat_message.created_at).notify_new
          end

          ::Chat::Publisher.publish_processed!(chat_message)
        end
      end
    end
  end
end
