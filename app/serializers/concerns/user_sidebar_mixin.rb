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
    SiteSetting.tagging_enabled && sidebar_navigation_menu?
  end

  def sidebar_category_ids
    object.category_sidebar_section_links.pluck(:linkable_id) & scope.allowed_category_ids
  end

  def include_sidebar_category_ids?
    sidebar_navigation_menu?
  end

  def sidebar_sections
    object
      .sidebar_sections
      .order(created_at: :asc)
      .includes(sidebar_section_links: :linkable)
      .map { |section| SidebarSectionSerializer.new(section, root: false) }
  end

  def include_sidebar_sections?
    sidebar_navigation_menu?
  end

  private

  def sidebar_navigation_menu?
    !SiteSetting.legacy_navigation_menu? ||
      %w[sidebar header_dropdown].include?(options[:navigation_menu_param])
  end
end
