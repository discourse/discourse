# frozen_string_literal: true

module UserSidebarTagsMixin
  def self.included(base)
    base.attributes :display_sidebar_tags

    base.has_many :sidebar_tags, serializer: Sidebar::TagSerializer, embed: :objects
  end

  def include_sidebar_tags?
    include_display_sidebar_tags?
  end

  def display_sidebar_tags
    DiscourseTagging.filter_visible(Tag, scope).exists?
  end

  def include_display_sidebar_tags?
    SiteSetting.tagging_enabled && SiteSetting.enable_experimental_sidebar_hamburger
  end
end
