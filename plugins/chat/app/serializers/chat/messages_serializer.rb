# frozen_string_literal: true

module Chat
  class MessagesSerializer < ::ApplicationSerializer
    attributes :messages, :tracking, :meta

    def initialize(object, opts)
      super(object, opts)
      @opts = opts
    end

    def messages
      object.messages.map do |message|
        ::Chat::MessageSerializer.new(
          message,
          scope: scope,
          root: false,
          include_thread_preview: true,
          include_thread_original_message: true,
          thread_participants: object.thread_participants,
          thread_memberships: object.thread_memberships,
          **@opts,
        )
      end
    end

    def tracking
      object.tracking || {}
    end

    def meta
      {
        target_message_id: object.target_message_id,
        can_load_more_future: object.can_load_more_future,
        can_load_more_past: object.can_load_more_past,
      }
    end
  end
end
