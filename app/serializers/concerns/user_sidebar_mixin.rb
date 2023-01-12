# frozen_string_literal: true

module UserSidebarMixin
  def sidebar_tags
    topic_count_column = Tag.topic_count_column(scope)

    object
      .visible_sidebar_tags(scope)
      .pluck(:name, topic_count_column, :pm_topic_count)
      .reduce([]) do |tags, sidebar_tag|
        tags.push(name: sidebar_tag[0], pm_only: sidebar_tag[1] == 0 && sidebar_tag[2] > 0)
      end
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

  def sidebar_list_destination
    if object.user_option.sidebar_list_none_selected?
      SiteSetting.default_sidebar_list_destination
    else
      object.user_option.sidebar_list_destination
    end
  end

  def include_sidebar_list_destination?
    sidebar_navigation_menu?
  end

  private

  def sidebar_navigation_menu?
    !SiteSetting.legacy_navigation_menu? || options[:enable_sidebar_param] == "1"
  end
end
