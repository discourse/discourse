class EmailLogSerializer < ApplicationSerializer
  include EmailLogsMixin

  attributes :reply_key,
             :bounced

  has_one :user, serializer: BasicUserSerializer, embed: :objects
end
