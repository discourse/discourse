# frozen_string_literal: true

class ChatChannelSearchSerializer < StructuredChannelSerializer
  has_many :users, serializer: BasicUserSerializer, embed: :objects

  def users
    object[:users]
  end
end
