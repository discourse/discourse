# frozen_string_literal: true

module Chat
  class ThreadSerializer < ApplicationSerializer
    has_one :original_message, serializer: Chat::ThreadOriginalMessageSerializer, embed: :objects

    attributes :id,
               :title,
               :status,
               :channel_id,
               :meta,
               :reply_count,
               :current_user_membership,
               :preview

    def initialize(object, opts)
      super(object, opts)
      @opts = opts

      # Avoids an N1 to re-load the thread in the serializer for original_message.
      object.original_message&.thread = object
      @current_user_membership = opts[:membership]
    end

    def include_original_message?
      @opts[:include_thread_original_message].presence || true
    end

    def meta
      { message_bus_last_ids: { thread_message_bus_last_id: thread_message_bus_last_id } }
    end

    def reply_count
      object.replies_count_cache || 0
    end

    def include_preview?
      @opts[:include_thread_preview]
    end

    def preview
      Chat::ThreadPreviewSerializer.new(
        object,
        scope: scope,
        root: false,
        participants: @opts[:participants],
      ).as_json
    end

    def include_current_user_membership?
      @current_user_membership.present?
    end

    def current_user_membership
      @current_user_membership.thread = object

      Chat::BaseThreadMembershipSerializer.new(
        @current_user_membership,
        scope: scope,
        root: false,
      ).as_json
    end

    private

    def thread_message_bus_last_id
      @opts[:thread_message_bus_last_id] ||
        MessageBus.last_id(Chat::Publisher.thread_message_bus_channel(object.channel_id, object.id))
    end
  end
end
