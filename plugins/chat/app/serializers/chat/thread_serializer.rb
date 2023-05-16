# frozen_string_literal: true

module Chat
  class ThreadSerializer < ApplicationSerializer
    has_one :original_message_user, serializer: BasicUserWithStatusSerializer, embed: :objects
    has_one :original_message, serializer: Chat::ThreadOriginalMessageSerializer, embed: :objects

    attributes :id, :title, :status, :channel_id, :meta, :reply_count

    def initialize(object, opts)
      super(object, opts)
      @opts = opts

      # Avoids an N1 to re-load the thread in the serializer for original_message.
      object.original_message.thread = object
    end

    def meta
      { message_bus_last_ids: { thread_message_bus_last_id: thread_message_bus_last_id } }
    end

    def reply_count
      object.replies_count_cache || 0
    end

    private

    def thread_message_bus_last_id
      @opts[:thread_message_bus_last_id] ||
        MessageBus.last_id(Chat::Publisher.thread_message_bus_channel(object.channel_id, object.id))
    end
  end
end
