# frozen_string_literal: true

module UserSidebarMixin
  include NavigationMenuTagsMixin

  def sidebar_tags
    serialize_tags(object.visible_sidebar_tags(scope))
  end

  def display_sidebar_tags
    DiscourseTagging.filter_visible(Tag, scope).exists?
  end

  def include_display_sidebar_tags?
    include_sidebar_tags?
  end

  def include_sidebar_tags?
    SiteSetting.tagging_enabled
  end

  def sidebar_category_ids
    object.secured_sidebar_category_ids(scope)
  end
end
