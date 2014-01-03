class ApiKeySerializer < ApplicationSerializer

  attributes :id,
             :key

  has_one :user, serializer: BasicUserSerializer, embed: :objects

  def filter(keys)
    keys -= [ :user_id ] unless object.user_id.present?
    keys
  end

end
