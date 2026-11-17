# frozen_string_literal: true

module PageObjects
  module Components
    class BoardsAddFromTopic < PageObjects::Components::Base
      ADD_TO_BOARD_BUTTON = "#topic-footer-button-boards-add-from-topic"
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
        within(".discourse-boards-add-from-topic-column-menu") do
          find("button", exact_text: column.unicode_title).click
        end
        self
      end

      def has_no_add_to_board_button?
        has_no_css?(ADD_TO_BOARD_BUTTON)
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
