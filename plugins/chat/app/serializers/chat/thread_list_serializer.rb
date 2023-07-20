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
          include_preview: true,
          root: nil,
        )
      end
    end

    def tracking
      object.tracking
    end

    def meta
      { channel_id: object.channel.id, load_more_url: object.load_more_url }
    end
  end
end
