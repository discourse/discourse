class BadgeSerializer < ApplicationSerializer
  attributes :id, :name, :description, :grant_count, :allow_title,
             :multiple_grant, :icon, :image, :listable, :enabled, :badge_grouping_id,
             :system, :long_description, :slug

  has_one :badge_type

  def system
    object.system?
  end

  def include_long_description?
    options[:include_long_description]
  end

  def name
    object.display_name
  end
end
