# frozen_string_literal: true

module PageObjects
  module Pages
    class Review < PageObjects::Pages::Base
      POST_BODY_TOGGLE_SELECTOR = ".post-body__toggle-btn"
      POST_BODY_COLLAPSED_SELECTOR = ".post-body.is-collapsed"
      REVIEWABLE_ACTION_DROPDOWN = ".reviewable-action-dropdown"

      def visit_reviewable(reviewable)
        page.visit("/review/#{reviewable.id}")
        self
      end

      def select_bundled_action(reviewable, value)
        within(reviewable_by_id(reviewable.id)) do
          reviewable_action_dropdown.select_row_by_value(value)
        end
      end

      def reviewable_by_id(id)
        find(".reviewable-item[data-reviewable-id=\"#{id}\"]")
      end

      def click_post_body_toggle
        find(POST_BODY_TOGGLE_SELECTOR).click
      end

      def has_post_body_toggle?
        page.has_css?(POST_BODY_TOGGLE_SELECTOR)
      end

      def has_no_post_body_toggle?
        page.has_no_css?(POST_BODY_TOGGLE_SELECTOR)
      end

      def has_post_body_collapsed?
        page.has_css?(POST_BODY_COLLAPSED_SELECTOR)
      end

      def has_no_post_body_collapsed?
        page.has_no_css?(POST_BODY_COLLAPSED_SELECTOR)
      end

      def has_reviewable_action_dropdown?
        page.has_css?(REVIEWABLE_ACTION_DROPDOWN)
      end

      def has_no_reviewable_action_dropdown?
        page.has_no_css?(REVIEWABLE_ACTION_DROPDOWN)
      end

      def has_reviewable_with_pending_status?(reviewable)
        within(reviewable_by_id(reviewable.id)) { page.has_css?(".status .pending") }
      end

      def has_reviewable_with_rejected_status?(reviewable)
        within(reviewable_by_id(reviewable.id)) { page.has_css?(".status .rejected") }
      end

      def has_error_dialog_visible?
        page.has_css?(".dialog-container .dialog-content")
      end

      def has_no_error_dialog_visible?
        page.has_no_css?("dialog-container .dialog-content")
      end

      private

      def reviewable_action_dropdown
        @reviewable_action_dropdown ||=
          PageObjects::Components::SelectKit.new(REVIEWABLE_ACTION_DROPDOWN)
      end
    end
  end
end
