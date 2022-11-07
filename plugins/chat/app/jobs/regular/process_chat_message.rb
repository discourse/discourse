# frozen_string_literal: true

module Jobs
  class ProcessChatMessage < ::Jobs::Base
    def execute(args = {})
      DistributedMutex.synchronize(
        "process_chat_message_#{args[:chat_message_id]}",
        validity: 10.minutes,
      ) do
        chat_message = ChatMessage.find_by(id: args[:chat_message_id])
        return if !chat_message
        processor = Chat::ChatMessageProcessor.new(chat_message)
        processor.run!

        if args[:is_dirty] || processor.dirty?
          chat_message.update(cooked: processor.html, cooked_version: ChatMessage::BAKED_VERSION)
          ChatPublisher.publish_processed!(chat_message)
        end
      end
    end
  end
end
