# frozen_string_literal: true

module PageObjects
  module Components
    class BoardsBoard < PageObjects::Components::Base
      def has_name?(name)
        has_css?(".discourse-boards-board-viewer__title", text: name)
      end

      def board_menu
        PageObjects::Components::DMenu.new(
          find(
            ".discourse-boards-board-viewer__controls [data-identifier='boards-board-controls']",
          ),
        )
      end

      def open_board_menu
        board_menu.expand
        self
      end

      def click_board_settings_menu_item
        board_menu.option("[data-identifier='board-settings']").click
        self
      end

      def click_add_column_menu_item
        board_menu.option("[data-identifier='add-column']").click
        self
      end

      def click_delete_board_menu_item
        board_menu.option("[data-identifier='delete-board']").click
        self
      end

      def has_no_menu_item?(identifier)
        board_menu.has_no_option?("[data-identifier='#{identifier}']")
        self
      end
    end
  end
end
