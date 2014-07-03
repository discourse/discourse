class BadgeSerializer < ApplicationSerializer
  attributes :id, :name, :description, :grant_count, :allow_title, :multiple_grant, :icon, :listable

  has_one :badge_type
end
