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

  def long_description
    if object.long_description.present?
      object.long_description
    else
      key = "badges.long_descriptions.#{i18n_name}"
      if I18n.exists?(key)
        I18n.t(key)
      else
        ""
      end
    end
  end

  def slug
    Slug.for(display_name, '')
  end

  private

  def i18n_name
    object.name.downcase.gsub(' ', '_')
  end

  def display_name
    key = "admin_js.badges.badge.#{i18n_name}.name"
    I18n.t(key, default: object.name)
  end
end
