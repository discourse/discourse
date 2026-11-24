# frozen_string_literal: true

module PageObjects
  module Pages
    class UserPreferencesNavigationMenu < PageObjects::Pages::Base
      def visit(user)
        page.visit("/u/#{user.username}/preferences/navigation-menu")
        self
      end

      def has_navigation_menu_categories_preference?(*categories)
        selector = ".category-selector"
        if find(selector).matches_css?(".d-select", wait: 0)
          PageObjects::Components::UiKit::DSelect.at(selector).has_selected_names?(
            *categories.map(&:name),
          )
        else
          category_selector_header = page.find("#{selector} .select-kit-header-wrapper")
          category_selector_header.has_content?(categories.map(&:name).join(", "))
        end
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
