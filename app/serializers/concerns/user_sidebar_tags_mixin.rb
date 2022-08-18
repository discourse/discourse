# frozen_string_literal: true

module UserSidebarTagsMixin
  def self.included(base)
    base.has_many :sidebar_tags, serializer: Sidebar::TagSerializer, embed: :objects
  end

  def include_sidebar_tags?
    SiteSetting.enable_experimental_sidebar_hamburger && SiteSetting.tagging_enabled
  end
end
