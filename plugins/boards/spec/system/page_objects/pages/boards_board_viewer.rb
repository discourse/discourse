# frozen_string_literal: true

module PageObjects
  module Pages
    class BoardsBoardViewer < PageObjects::Pages::Base
      def visit_board(board)
        page.visit "/boards/#{board.slug}/#{board.id}"
        self
      end

      def visit_board_with_slug(slug, board)
        page.visit "/boards/#{slug}/#{board.id}"
        self
      end

      def has_column?(title)
        has_css?(".discourse-boards-column__title", text: /#{Regexp.escape(title)}/i)
      end

      def has_no_column?(title)
        has_no_css?(".discourse-boards-column__title", text: /#{Regexp.escape(title)}/i)
      end

      def has_card_in_column?(column_title, card_title)
        within(find(".discourse-boards-column", text: /#{Regexp.escape(column_title)}/i)) do
          has_css?(".discourse-boards-card__title", text: card_title)
        end
      end

      def has_no_card_in_column?(column_title, card_title)
        within(find(".discourse-boards-column", text: /#{Regexp.escape(column_title)}/i)) do
          has_no_css?(".discourse-boards-card__title", text: card_title)
        end
      end

      def card_count_in_column(column_title)
        within(find(".discourse-boards-column", text: /#{Regexp.escape(column_title)}/i)) do
          all(".discourse-boards-card").count
        end
      end

      def drag_card_to_column(card_title, target_column_title)
        find(".discourse-boards-card", text: card_title).drag_to(
          find(".discourse-boards-column", text: /#{Regexp.escape(target_column_title)}/i),
          html5: true,
          delay: 0.4,
        )
        self
      end

      def has_board_title?(title)
        has_css?(".discourse-boards-board-viewer__title", text: title)
      end

      def card_draggable?(card_title)
        find(".discourse-boards-card", text: card_title)["draggable"] == "true"
      end

      def has_tag_on_card?(card_title, tag_name)
        within(find(".discourse-boards-card", text: card_title)) do
          has_css?(".discourse-tag", text: tag_name)
        end
      end

      def has_no_tag_on_card?(card_title, tag_name)
        within(find(".discourse-boards-card", text: card_title)) do
          has_no_css?(".discourse-tag", text: tag_name)
        end
      end

      def has_category_on_card?(card_title)
        within(find(".discourse-boards-card", text: card_title)) do
          has_css?(".discourse-boards-card__category")
        end
      end

      def has_activity_indicator?(card_title, type)
        has_css?(".discourse-boards-card.#{type}", text: card_title)
      end

      def has_add_card_button_in_column?(column_title)
        within(find(".discourse-boards-column", text: /#{Regexp.escape(column_title)}/i)) do
          has_css?(".discourse-boards-column__add-btn")
        end
      end

      def has_no_add_card_button_in_column?(column_title)
        within(find(".discourse-boards-column", text: /#{Regexp.escape(column_title)}/i)) do
          has_no_css?(".discourse-boards-column__add-btn")
        end
      end

      def click_add_card(column_title)
        within(find(".discourse-boards-column", text: /#{Regexp.escape(column_title)}/i)) do
          find(".discourse-boards-column__add-btn").click
        end
        find(
          "[data-content][data-identifier='boards-column-add'] .btn-transparent",
          text: I18n.t("js.boards.board.add_card"),
        ).click
        has_css?(".discourse-boards-card-detail-modal")
        self
      end

      def click_add_topic_as_card(column_title)
        within(find(".discourse-boards-column", text: /#{Regexp.escape(column_title)}/i)) do
          find(".discourse-boards-column__add-btn").click
        end
        find(
          "[data-content][data-identifier='boards-column-add'] .btn-transparent",
          text: I18n.t("js.boards.board.add_topic_as_card"),
        ).click
        has_css?(".discourse-boards-add-topic-as-card-modal")
        self
      end

      def fill_topic_search(value)
        within(".discourse-boards-add-topic-as-card-modal") do
          find("input.topic-search-input").fill_in(with: value)
        end
        self
      end

      def select_topic_search_result(topic_id)
        find(".internal-link-results a[data-topic-id='#{topic_id}']").click
        self
      end

      def submit_topic_search
        within(".discourse-boards-add-topic-as-card-modal") do
          find(".d-modal__footer .btn-primary").click
        end
        self
      end

      def submit_topic_search_with_enter
        within(".discourse-boards-add-topic-as-card-modal") do
          find("input.topic-search-input").send_keys(:enter)
        end
        self
      end

      def has_no_add_topic_as_card_modal?
        has_no_css?(".discourse-boards-add-topic-as-card-modal")
      end

      def fill_card_title(title)
        fill_card_detail_title(title)
      end

      def submit_card
        save_card_detail
      end

      def has_floater_card_in_column?(column_title, card_title)
        within(find(".discourse-boards-column", text: /#{Regexp.escape(column_title)}/i)) do
          has_css?(".discourse-boards-card--floater", text: card_title)
        end
      end

      def open_card_actions(card_title)
        within(find(".discourse-boards-card", text: card_title)) do
          find(".discourse-boards-card__actions-trigger", visible: :all).click
        end
        self
      end

      def has_edit_card_action?
        has_css?(
          "[data-content][data-identifier='boards-card-actions'] .btn-transparent .d-button-label",
          text: I18n.t("js.edit"),
        )
      end

      def click_edit_card
        find(
          "[data-content][data-identifier='boards-card-actions'] .btn-transparent",
          text: I18n.t("js.edit"),
        ).click
        self
      end

      def has_card_detail_modal?
        has_css?(".discourse-boards-card-detail-modal")
      end

      def fill_card_detail_title(new_title)
        within(".discourse-boards-card-detail-modal") do
          if has_css?(".discourse-boards-editable-title__input", wait: 0)
            find(".discourse-boards-editable-title__input").set(new_title)
          else
            find(".discourse-boards-editable-title__text").click
            find(".discourse-boards-editable-title__input").set(new_title)
          end
        end
        self
      end

      def select_card_detail_tag(tag_name)
        tag_chooser =
          PageObjects::Components::SelectKit.new(".discourse-boards-card-detail-modal .tag-chooser")
        tag_chooser.expand
        tag_chooser.search(tag_name)
        tag_chooser.select_row_by_name(tag_name)
        tag_chooser.collapse
        self
      end

      def create_card_detail_tag(tag_name)
        tag_chooser =
          PageObjects::Components::SelectKit.new(".discourse-boards-card-detail-modal .tag-chooser")
        tag_chooser.expand
        tag_chooser.search(tag_name)
        tag_chooser.select_row_by_value(tag_name)
        tag_chooser.collapse
        self
      end

      def has_card_detail_tag?(tag_name)
        tag_chooser =
          PageObjects::Components::SelectKit.new(".discourse-boards-card-detail-modal .tag-chooser")
        tag_chooser.has_selected_name?(tag_name)
      end

      def save_card_detail
        within(".discourse-boards-card-detail-modal") do
          find(".form-kit__actions button[type='submit']").click
        end
        self
      end

      def cancel_card_detail
        within(".discourse-boards-card-detail-modal") do
          find(".d-modal-cancel", text: I18n.t("js.cancel")).click
        end
        self
      end

      def has_fullscreen?
        has_css?(".discourse-boards-board-viewer.discourse-boards-board-viewer--fullscreen")
      end

      def has_no_fullscreen?
        has_no_css?(".discourse-boards-board-viewer.discourse-boards-board-viewer--fullscreen")
      end

      def open_controls_menu
        find(
          ".discourse-boards-board-viewer__controls [data-identifier='boards-board-controls']",
        ).click
        self
      end

      def has_no_controls_menu?
        has_no_css?(
          ".discourse-boards-board-viewer__controls [data-identifier='boards-board-controls']",
        )
      end

      def click_fullscreen
        find(
          ".discourse-boards-board-viewer__controls .btn-flat[title='#{I18n.t("js.boards.board.fullscreen")}']",
        ).click
        self
      end

      def click_exit_fullscreen
        find(".discourse-boards-board-viewer__exit-fullscreen").click
        self
      end

      def has_board_settings_option?
        has_css?(
          "[data-content][data-identifier='boards-board-controls'] .btn-transparent .d-button-label",
          text: I18n.t("js.boards.board.board_settings"),
        )
      end

      def has_no_board_settings_option?
        has_no_css?(
          "[data-content][data-identifier='boards-board-controls'] .btn-transparent .d-button-label",
          text: I18n.t("js.boards.board.board_settings"),
        )
      end

      def visit_card(board, card)
        page.visit "/boards/#{board.slug}/#{board.id}/cards/#{card.id}"
        self
      end

      def has_no_card_detail_modal?
        has_no_css?(".discourse-boards-card-detail-modal")
      end

      def click_floater_card(card_title)
        find(".discourse-boards-card--floater", text: card_title).click
        self
      end

      def has_card_tag?(card_title, tag_name)
        within(find(".discourse-boards-card--floater", text: card_title)) do
          has_css?(".discourse-tag", text: tag_name)
        end
      end

      def has_card_notes_indicator?(card_title)
        within(find(".discourse-boards-card--floater", text: card_title)) do
          has_css?(".discourse-boards-card__notes-indicator")
        end
      end

      def click_topic_card(card_title)
        find(".discourse-boards-card:not(.discourse-boards-card--floater)", text: card_title).click
        self
      end

      def has_topic_card_detail_modal?
        has_css?(".discourse-boards-topic-card-detail-modal")
      end

      def has_no_topic_card_detail_modal?
        has_no_css?(".discourse-boards-topic-card-detail-modal")
      end

      def has_topic_card_detail_cooked?
        within(".discourse-boards-topic-card-detail-modal") do
          has_css?(".discourse-boards-topic-card-detail__cooked")
        end
      end

      def has_topic_card_detail_category?
        within(".discourse-boards-topic-card-detail-modal") { has_css?(".badge-category__wrapper") }
      end

      def has_topic_card_detail_tags?
        within(".discourse-boards-topic-card-detail-modal") do
          has_css?(".discourse-boards-topic-card-detail__tags")
        end
      end

      def has_topic_card_detail_reply_count?
        within(".discourse-boards-topic-card-detail-modal") do
          has_css?(".discourse-boards-topic-card-detail__stats")
        end
      end

      def click_topic_card_view_topic
        within(".discourse-boards-topic-card-detail-modal") { find(".btn-primary").click }
        self
      end

      def has_constraint_fix_modal?
        has_css?(".discourse-boards-constraint-fix-modal")
      end

      def click_constraint_fix_category(category_id)
        find(".discourse-boards-constraint-fix-modal [data-category-id='#{category_id}']").click
        self
      end

      def click_constraint_fix_tag(tag_name)
        find(".discourse-boards-constraint-fix-modal [data-tag-name='#{tag_name}']").click
        self
      end

      def click_constraint_fix_confirm
        PageObjects::Modals::Base.new(
          body_selector: ".discourse-boards-constraint-fix-modal",
        ).click_primary_button
        self
      end
    end
  end
end
