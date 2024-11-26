# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminEmojis < PageObjects::Pages::Base
      def visit_page
        page.visit "/admin/customize/emojis"
        self
      end

      def click_tab(tab_name)
        case tab_name
        when "settings"
          find(".admin-emojis-tabs__settings").click
        when "index"
          find(".admin-emojis-tabs__emoji").click
        end
      end

      def has_emoji_listed?(name)
        page.has_css?(emoji_table_selector, text: name)
      end

      def has_no_emoji_listed?(name)
        page.has_no_css?(emoji_table_selector, text: name)
      end

      def delete_emoji(name)
        find(".d-admin-row__content", text: name).find(delete_button_selector).click
      end

      private

      def emoji_table_selector
        "#custom_emoji"
      end

      def delete_button_selector
        ".d-admin-row__controls-delete"
      end
    end
  end
end
