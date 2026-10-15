# frozen_string_literal: true

module PageObjects
  module Pages
    class UserPreferencesNavigationMenu < PageObjects::Pages::Base
      def visit(user)
        browser_page
          .goto("/u/#{user.username}/preferences/navigation-menu")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def has_navigation_menu_categories_preference?(*categories)
        category_selector_header =
          browser_root.locator(".category-selector .select-kit-header-wrapper").filter(
            visible: true,
          )
        PlaywrightMatchers.contain_text(
          browser_text_pattern(categories.map(&:name).join(", ")),
          useInnerText: true,
        ).matches?(category_selector_header)
      end

      def has_navigation_menu_tags_preference?(*tags)
        tag_selector_header =
          browser_root.locator(".tag-chooser .select-kit-header-wrapper").filter(visible: true)
        PlaywrightMatchers.contain_text(
          browser_text_pattern(tags.map(&:name).join(", ")),
          useInnerText: true,
        ).matches?(tag_selector_header)
      end

      def has_navigation_menu_preference_checked?(preference)
        browser_root.locator(".#{preference} input").filter(visible: true).checked?
      end
    end
  end
end
