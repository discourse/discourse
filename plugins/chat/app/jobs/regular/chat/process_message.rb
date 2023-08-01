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
          processor = ::Chat::MessageProcessor.new(chat_message)
          processor.run!

          if args[:is_dirty] || processor.dirty?
            chat_message.update(
              cooked: processor.html,
              cooked_version: ::Chat::Message::BAKED_VERSION,
            )
            ::Chat::Publisher.publish_processed!(chat_message)
          end
        end
      end
    end
  end
end
