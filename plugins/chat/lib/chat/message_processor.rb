# frozen_string_literal: true

module Chat
  class MessageProcessor
    include ::CookedProcessorMixin

    def initialize(chat_message)
      @model = chat_message
      @previous_cooked = (chat_message.cooked || "").dup
      @with_secure_uploads = false
      @size_cache = {}
      @opts = {}

      cooked = Chat::Message.cook(chat_message.message, user_id: chat_message.last_editor_id)
      @doc = Loofah.fragment(cooked)
    end

    def run!
      post_process_oneboxes
      DiscourseEvent.trigger(:chat_message_processed, @doc, @model)
    end

    def large_images
      []
    end

    def broken_images
      []
    end

    def downloaded_images
      {}
    end
  end
end
