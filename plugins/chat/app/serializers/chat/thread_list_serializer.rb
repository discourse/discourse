# frozen_string_literal: true

module Chat
  class ThreadListSerializer < ApplicationSerializer
    attributes :meta, :threads

    def threads
      ActiveModel::ArraySerializer.new(
        object.threads,
        each_serializer: Chat::ThreadSerializer,
        scope: scope,
      )
    end

    def meta
      { channel_id: object.channel.id }
    end
  end
end
