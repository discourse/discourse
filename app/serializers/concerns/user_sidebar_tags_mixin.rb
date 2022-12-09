# frozen_string_literal: true

module UserSidebarTagsMixin
  def self.included(base)
    base.attributes :display_sidebar_tags,
                    :sidebar_tags
  end

  def sidebar_tags
    object.visible_sidebar_tags(scope)
      .pluck(:name, :topic_count, :pm_topic_count)
      .reduce([]) do |tags, sidebar_tag|
        tags.push(
          name: sidebar_tag[0],
          pm_only: sidebar_tag[1] == 0 && sidebar_tag[2] > 0
        )
      end
  end

  def include_sidebar_tags?
    include_display_sidebar_tags?
  end

  def display_sidebar_tags
    DiscourseTagging.filter_visible(Tag, scope).exists?
  end

  def include_display_sidebar_tags?
    SiteSetting.tagging_enabled && !SiteSetting.legacy_navigation_menu?
  end
end
