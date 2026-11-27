# frozen_string_literal: true

module PageObjects
  module Components
    class BoardsAddFromTopic < PageObjects::Components::Base
      ADD_TO_BOARD_BUTTON = "#topic-footer-button-boards-add-from-topic"
      COLUMN_MENU = ".discourse-boards-add-from-topic-column-menu"
      MEMBERSHIP_PILL = "#topic-title .discourse-boards-topic-pill"

      def add_to_column(board, column)
        select_column(board, column)
      end

      def remove_from_column(board, column)
        select_column(board, column)
      end

      def select_column(board, column)
        find(ADD_TO_BOARD_BUTTON).click
        within(".discourse-boards-add-from-topic-menu") do
          find("button", exact_text: board.unicode_name).click
        end
        within(COLUMN_MENU) { find("button", exact_text: column.unicode_title).click }
        self
      end

      def has_no_add_to_board_button?
        has_no_css?(ADD_TO_BOARD_BUTTON)
      end

      def icon_color
        find("#{ADD_TO_BOARD_BUTTON} .d-icon").style("color")
      end

      def tap_board(board)
        locator(ADD_TO_BOARD_BUTTON).tap_point
        locator(".discourse-boards-add-from-topic-menu").get_by_role(
          "button",
          name: board.unicode_name,
          exact: true,
        ).tap_point
      end

      def has_column_sheet_for?(board)
        sheet =
          find("[role='dialog'][data-identifier='discourse-boards-add-from-topic-column-menu']")
        sheet["aria-label"] == board.unicode_name &&
          sheet.has_css?("h2", exact_text: board.unicode_name)
      end

      def tap_view_board
        locator(COLUMN_MENU).get_by_role(
          "link",
          name: I18n.t("js.boards.manage.view_board"),
        ).tap_point
      end

      def has_membership?(board, column)
        has_css?(MEMBERSHIP_PILL, exact_text: board.unicode_name) do |pill|
          pill["title"] ==
            I18n.t(
              "js.boards.topic_pill.title",
              board: board.unicode_name,
              column: column.unicode_title,
            )
        end
      end

      def has_membership_count?(count)
        has_css?(
          "#{MEMBERSHIP_PILL}.discourse-boards-topic-pill--multiple",
          exact_text: I18n.t("js.boards.topic_pill.multiple", count:),
        )
      end

      def open_memberships
        find("#{MEMBERSHIP_PILL}.discourse-boards-topic-pill--multiple").click
        self
      end

      def has_membership_in_menu?(board, column)
        within("[data-content][data-identifier='discourse-boards-topic-pill']") do
          find(".discourse-boards-boards-menu__item", text: board.unicode_name).has_css?(
            ".discourse-boards-boards-menu__column",
            text: /#{Regexp.escape(column.unicode_title)}/i,
          )
        end
      end
    end
  end
end
