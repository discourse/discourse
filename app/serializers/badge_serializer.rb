class BadgeSerializer < ApplicationSerializer
  attributes :id, :name, :description, :grant_count, :allow_title,
             :multiple_grant, :icon, :image, :listable, :enabled, :badge_grouping_id,
             :system
  has_one :badge_type

  def system
    object.system?
  end
end
