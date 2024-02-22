# frozen_string_literal: true

module PageObjects
  module Pages
    class UserPreferencesNavigationMenu < PageObjects::Pages::Base
      def visit(user)
        page.visit("/u/#{user.username}/preferences/navigation-menu")
        self
      end

      def has_navigation_menu_categories_preference?(*categories)
        category_selector_header = page.find(".category-selector .select-kit-header-wrapper")
        category_selector_header.has_content?(categories.map(&:name).join(", "))
      end

      def has_navigation_menu_tags_preference?(*tags)
        tag_selector_header = page.find(".tag-chooser .select-kit-header-wrapper")
        tag_selector_header.has_content?(tags.map(&:name).join(", "))
      end

      def has_navigation_menu_preference_checked?(preference)
        page.find(".#{preference} input").checked?
      end
    end
  end
end
