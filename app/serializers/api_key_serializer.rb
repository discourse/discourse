class ApiKeySerializer < ApplicationSerializer

  attributes :id,
             :key

  has_one :user, serializer: BasicUserSerializer, embed: :objects

  def filter(keys)
    keys.delete(:user_id) if object.user_id.nil?
    super(keys)
  end

end
