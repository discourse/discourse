class UserBadgeSerializer < ApplicationSerializer
  attributes :id, :granted_at

  has_one :badge
  has_one :user, serializer: BasicUserSerializer, root: :users
  has_one :granted_by, serializer: BasicUserSerializer, root: :users
end
