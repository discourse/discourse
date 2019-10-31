# frozen_string_literal: true

class SiteCategorySerializer < BasicCategorySerializer

  attributes :allowed_tags,
             :allowed_tag_groups,
             :allow_global_tags

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

end
