# frozen_string_literal: true

module Chat
  class ThreadListSerializer < ApplicationSerializer
    attributes :meta, :threads, :tracking

    def threads
      object.threads.map do |thread|
        Chat::ThreadSerializer.new(
          thread,
          scope: scope,
          membership: object.memberships.find { |m| m.thread_id == thread.id },
          root: nil,
        )
      end
    end

    def tracking
      object.tracking
    end

    def meta
      { channel_id: object.channel.id }
    end
  end
end
