class UserBadgesSerializer < ApplicationSerializer
  has_many :user_badges, embed: :objects
  attributes :grant_count, :username
end
