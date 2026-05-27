# frozen_string_literal: true

module Chat
  class ChannelPinsSerializer < ApplicationSerializer
    attributes :pinned_messages, :membership

    def pinned_messages
      ActiveModel::ArraySerializer.new(
        object[:pins],
        each_serializer: Chat::PinnedMessageSerializer,
        scope: scope,
      )
    end

    def membership
      return if !object[:membership]

      Chat::UserChannelMembershipSerializer.new(object[:membership], scope: scope, root: false)
    end
  end
end
