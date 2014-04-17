class BadgeSerializer < ApplicationSerializer
  attributes :id, :name, :description, :grant_count

  has_one :badge_type
end
