class ApiKeySerializer < ApplicationSerializer

  attributes :id,
             :key

  has_one :user, serializer: BasicUserSerializer, embed: :objects

  def include_user_id?
    !object.user_id.nil?
  end

end
