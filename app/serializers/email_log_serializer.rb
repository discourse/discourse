class EmailLogSerializer < ApplicationSerializer

  attributes :id, :to_address, :email_type, :user_id, :created_at
  has_one :user, serializer: BasicUserSerializer, embed: :objects

end
