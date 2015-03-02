class BadgeSerializer < ApplicationSerializer
  attributes :id, :name, :description, :grant_count, :allow_title,
             :multiple_grant, :icon, :image, :listable, :enabled, :badge_grouping_id,
             :system, :long_description

  has_one :badge_type

  def system
    object.system?
  end

  def include_long_description?
    options[:include_long_description]
  end

  def long_description
    if object.long_description.present?
      object.long_description
    else
      key = "badges.long_descriptions.#{object.name.downcase.gsub(" ", "_")}"
      if I18n.exists?(key)
        I18n.t(key)
      else
        ""
      end
    end
  end
end
