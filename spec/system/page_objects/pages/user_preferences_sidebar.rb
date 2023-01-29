# frozen_string_literal: true

module PageObjects
  module Pages
    class UserPreferencesSidebar < PageObjects::Pages::Base
      def visit(user)
        page.visit("/u/#{user.username}/preferences/sidebar")
        self
      end

      def has_sidebar_categories_preference?(*categories)
        category_selector_header = page.find(".category-selector .select-kit-header-wrapper")
        category_selector_header.has_content?(categories.map(&:name).join(", "))
      end

      def has_sidebar_tags_preference?(*tags)
        tag_selector_header = page.find(".tag-chooser .select-kit-header-wrapper")
        tag_selector_header.has_content?(tags.map(&:name).join(", "))
      end

      def has_sidebar_list_destination_preference?(type)
        list_selector_header =
          page.find(
            ".preferences-sidebar-navigation__list-destination-selector .select-kit-header-wrapper",
          )
        list_selector_header.has_content?(
          I18n.t("js.user.experimental_sidebar.list_destination_#{type}"),
        )
      end
    end
  end
end
