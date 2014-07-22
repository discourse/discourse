class BadgeSerializer < ApplicationSerializer
  attributes :id, :name, :description, :grant_count, :allow_title,
             :multiple_grant, :icon, :listable, :enabled, :badge_grouping_id
  has_one :badge_type
end
