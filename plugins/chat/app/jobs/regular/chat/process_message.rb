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
            chat_message.upsert_mentions

            if args[:edit_timestamp]
              ::Chat::Publisher.publish_edit!(chat_message.chat_channel, chat_message)
              ::Chat::Notifier.new(chat_message, args[:edit_timestamp]).notify_edit
              DiscourseEvent.trigger(
                :chat_message_edited,
                chat_message,
                chat_message.chat_channel,
                chat_message.user,
              )
            else
              ::Chat::Publisher.publish_new!(
                chat_message.chat_channel,
                chat_message,
                args[:staged_id],
              )
              ::Chat::Notifier.new(chat_message, chat_message.created_at).notify_new
              DiscourseEvent.trigger(
                :chat_message_created,
                chat_message,
                chat_message.chat_channel,
                chat_message.user,
              )
            end

            ::Chat::Publisher.publish_processed!(chat_message)
          end
        end
      end
    end
  end
end
