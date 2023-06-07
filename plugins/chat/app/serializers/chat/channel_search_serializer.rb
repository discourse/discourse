# frozen_string_literal: true

module Chat
  class ChannelSearchSerializer < ::Chat::StructuredChannelSerializer
    has_many :users, serializer: ChatableUserSerializer, embed: :objects

    def users
      object[:users]
    end
  end
end
