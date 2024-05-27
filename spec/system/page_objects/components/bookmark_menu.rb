# frozen_string_literal: true

module PageObjects
  module Components
    class BookmarkMenu < PageObjects::Components::Base
      def click_menu_option(option_id)
        find(".bookmark-menu__row[data-menu-option-id='#{option_id}']").click
      end

      def open?
        has_css?(".bookmark-menu-content")
      end
    end
  end
end
