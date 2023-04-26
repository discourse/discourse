# frozen_string_literal: true

module Chat
  class ThreadSerializer < ApplicationSerializer
    has_one :original_message_user, serializer: BasicUserWithStatusSerializer, embed: :objects
    has_one :original_message, serializer: Chat::ThreadOriginalMessageSerializer, embed: :objects

    attributes :id, :title, :status, :channel_id, :meta

    def initialize(object, opts)
      super(object, opts)
      @opts = opts
    end

    def meta
      { message_bus_last_ids: { thread_message_bus_last_id: thread_message_bus_last_id } }
    end

    private

    def thread_message_bus_last_id
      @opts[:thread_message_bus_last_id] ||
        MessageBus.last_id(Chat::Publisher.thread_message_bus_channel(object.channel_id, object.id))
    end
  end
end
