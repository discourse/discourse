# frozen_string_literal: true

module Chat
  class DirectMessageSerializer < ApplicationSerializer
    attributes :id

    has_many :users, serializer: Chat::UserWithCustomFieldsAndStatusSerializer, embed: :objects

    def users
      users = object.direct_message_users.map(&:user).map { |u| u || Chat::DeletedUser.new }

      return users - [scope.user] if users.count > 1
      users
    end
  end
end
