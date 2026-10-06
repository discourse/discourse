# frozen_string_literal: true

module PageObjects
  module Pages
    class BoardsManageBoards < PageObjects::Pages::Base
      def visit_page
        page.visit "/boards"
        self
      end

      def board_settings_form
        PageObjects::Components::FormKit.new("#{board_settings_modal.full_body_selector} .form-kit")
      end

      def column_settings_form
        PageObjects::Components::FormKit.new(
          "#{column_settings_modal.full_body_selector} .form-kit",
        )
      end

      def click_new_board
        find(".discourse-boards-manage__new-board").click
        self
      end

      def has_board_listed?(name)
        has_css?(".discourse-boards-board-card", text: name)
      end

      def has_no_board_listed?(name)
        has_no_css?(".discourse-boards-board-card", text: name)
      end

      def has_empty_state?
        has_css?(".discourse-boards-boards-empty")
      end

      def has_new_board_button?
        has_css?(".discourse-boards-manage__new-board")
      end

      def has_no_new_board_button?
        has_no_css?(".discourse-boards-manage__new-board")
      end

      def click_board(board_name)
        find(".discourse-boards-board-card__name", text: board_name).click
        self
      end

      # Board settings modal interactions

      def board_settings_modal
        PageObjects::Modals::Base.new(modal_selector: ".discourse-boards-board-settings-modal")
      end

      def fill_modal_board_name(name)
        modal = board_settings_modal
        modal
          .body
          .find(".discourse-boards-editable-title__input, .discourse-boards-editable-title__text")
          .click
        modal.body.find(".discourse-boards-editable-title__input").fill_in(with: name)
        self
      end

      def toggle_modal_advanced_settings
        modal = board_settings_modal
        modal.body.find(".show-advanced").click
        self
      end

      def select_modal_board_tag(tag_name)
        modal = board_settings_modal
        chooser =
          PageObjects::Components::SelectKit.new(
            "#{modal.full_body_selector} [data-name='tag_names'] .form-kit__control-tag-chooser",
          )
        chooser.expand
        chooser.search(tag_name)
        chooser.select_row_by_name(tag_name)
        self
      end

      def save_board_modal
        modal = board_settings_modal
        modal.body.find(".discourse-boards-board-settings-modal__save-board").click
        self
      end

      def delete_from_board_modal
        modal = board_settings_modal
        modal.body.find(".discourse-boards-board-settings-modal__delete-board").click
        self
      end

      # Column settings modal interactions

      def column_settings_modal
        PageObjects::Modals::Base.new(modal_selector: ".discourse-boards-column-settings-modal")
      end

      def fill_modal_column_title(title)
        modal = column_settings_modal
        if modal.body.has_css?(".discourse-boards-editable-title__input", wait: 0)
          modal.body.find(".discourse-boards-editable-title__input").fill_in(with: title)
        else
          modal.body.find(".discourse-boards-editable-title__text").click
          modal.body.find(".discourse-boards-editable-title__input").fill_in(with: title)
        end
        self
      end

      def select_modal_column_tag(tag_name)
        modal = column_settings_modal
        chooser =
          PageObjects::Components::SelectKit.new("#{modal.full_body_selector} .mini-tag-chooser")
        chooser.expand
        chooser.search(tag_name)
        chooser.select_row_by_name(tag_name)
        self
      end

      def fill_modal_column_color(color)
        column_settings_form.field("color").fill_in(color)
      end

      def column_by_title(title)
        PageObjects::Components::BoardsColumn.new(title: title)
      end

      def open_column_menu(column_title)
        column = column_by_title(column_title)
        column.open_menu
        column
      end

      def save_column_modal
        modal = column_settings_modal
        modal.body.find(".discourse-boards-column-settings-modal__save").click
        self
      end

      def has_column?(title)
        column = column_by_title(title)
        column.exists?
      end
    end
  end
end
