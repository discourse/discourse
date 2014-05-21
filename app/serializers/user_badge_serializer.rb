class UserBadgeSerializer < ApplicationSerializer
  attributes :id, :granted_at, :count

  has_one :badge
  has_one :user, serializer: BasicUserSerializer, root: :users
  has_one :granted_by, serializer: BasicUserSerializer, root: :users

  def include_count?
    object.respond_to? :count
  end
end
