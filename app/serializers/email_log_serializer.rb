class EmailLogSerializer < ApplicationSerializer

  attributes :id,
             :reply_key,
             :to_address,
             :email_type,
             :user_id,
             :created_at

  has_one :user, serializer: BasicUserSerializer, embed: :objects

end
