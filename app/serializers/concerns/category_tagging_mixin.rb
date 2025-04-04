# frozen_string_literal: true

module CategoryTaggingMixin
  def self.included(base)
    base.attributes :allowed_tags, :allowed_tag_groups, :allow_global_tags

    base.has_many :category_required_tag_groups, key: :required_tag_groups
  end

  def include_allowed_tags?
    SiteSetting.tagging_enabled
  end

  def allowed_tags
    object.tags.pluck(:name)
  end

  def include_allowed_tag_groups?
    SiteSetting.tagging_enabled
  end

  def allowed_tag_groups
    object.tag_groups.pluck(:name)
  end

  def include_allow_global_tags?
    SiteSetting.tagging_enabled
  end

  def include_required_tag_groups?
    SiteSetting.tagging_enabled
  end
end
