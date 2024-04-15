# frozen_string_literal: true

module Chat
  class DirectMessageSerializer < ApplicationSerializer
    attributes :group, :users

    def users
      users = object.direct_message_users.map(&:user).map { |u| u || Chat::NullUser.new }
      users = users - [scope.user] if users.count > 1

      serializer =
        ActiveModel::ArraySerializer.new(
          users,
          each_serializer: ::Chat::ChatableUserSerializer,
          scope: scope,
          include_status: true,
        )

      serializer.as_json
    end
  end
end
