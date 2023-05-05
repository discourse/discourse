# frozen_string_literal: true

module Chat
  class ThreadIndexSerializer < ApplicationSerializer
    attributes :meta, :threads

    def threads
      ActiveModel::ArraySerializer.new(
        object.threads,
        each_serializer: Chat::ThreadSerializer,
        scope: scope,
      )
    end

    def meta
      {}
    end
  end
end
