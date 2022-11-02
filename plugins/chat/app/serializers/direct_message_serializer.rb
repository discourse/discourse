# frozen_string_literal: true

class DirectMessageSerializer < ApplicationSerializer
  has_many :users, serializer: UserWithCustomFieldsAndStatusSerializer, embed: :objects

  def users
    users = object.direct_message_users.map(&:user).map { |u| u || DeletedChatUser.new }

    return users - [scope.user] if users.count > 1
    users
  end
end
