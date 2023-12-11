# frozen_string_literal: true

module Chat
  class ThreadListSerializer < ApplicationSerializer
    attributes :meta, :threads, :tracking

    def threads
      object.threads.map do |thread|
        ::Chat::ThreadSerializer.new(
          thread,
          scope: scope,
          membership: object.memberships.find { |m| m.thread_id == thread.id },
          include_thread_preview: true,
          include_channel: true,
          include_thread_original_message: true,
          participants: object.threads_participants[thread.id],
          root: nil,
        )
      end
    end

    def tracking
      object.tracking
    end

    def meta
      meta = { load_more_url: object.load_more_url }
      meta[:channel_id] = object.channel.id if object.channel
      meta
    end
  end
end
