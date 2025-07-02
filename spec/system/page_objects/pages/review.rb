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

      def select_action(reviewable, value)
        within(reviewable_by_id(reviewable.id)) do
          find(".reviewable-action.#{value.dasherize}").click
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

      def has_reviewable_with_rejection_reason?(reviewable, rejection_reason)
        reviewable_by_id(reviewable.id).has_css?(
          ".reviewable-user-details.reject-reason .value",
          text: rejection_reason,
        )
      end

      def has_scrub_button?(reviewable)
        within(reviewable_by_id(reviewable.id)) { page.has_css?(".scrub-rejected-user button") }
      end

      def has_no_scrub_button?(reviewable)
        within(reviewable_by_id(reviewable.id)) { page.has_no_css?(".scrub-rejected-user button") }
      end

      def click_scrub_button(reviewable)
        within(reviewable_by_id(reviewable.id)) { find(".scrub-rejected-user button").click }
      end

      def has_reviewable_with_scrubbed_by?(reviewable, scrubbed_by)
        within(reviewable_by_id(reviewable.id)) do
          page.has_css?(".reviewable-user-details.scrubbed-by .value", text: scrubbed_by)
        end
      end

      def has_reviewable_with_scrubbed_reason?(reviewable, scrubbed_reason)
        within(reviewable_by_id(reviewable.id)) do
          page.has_css?(".reviewable-user-details.scrubbed-reason .value", text: scrubbed_reason)
        end
      end

      def has_reviewable_with_scrubbed_at?(reviewable, scrubbed_at)
        within(reviewable_by_id(reviewable.id)) do
          page.has_css?(".reviewable-user-details.scrubbed-at .value", text: scrubbed_at)
        end
      end

      def has_no_error_dialog_visible?
        page.has_no_css?("dialog-container .dialog-content")
      end

      def click_ignore_all_unknown_reviewables
        find(".unknown-reviewables__options button").click
        find(".dialog-footer .btn-danger").click
      end

      def has_information_about_unknown_reviewables_visible?
        page.has_css?(".unknown-reviewables")
      end

      def has_no_information_about_unknown_reviewables_visible?
        page.has_no_css?(".unknown-reviewables")
      end

      def has_listing_for_unknown_reviewables_plugin?(reviewable_type, plugin_name)
        page.has_css?(
          ".unknown-reviewables ul li",
          text:
            I18n.t(
              "js.review.unknown.reviewable_known_source",
              reviewableType: reviewable_type,
              pluginName: plugin_name,
            ),
        )
      end

      def has_listing_for_unknown_reviewables_unknown_source?(reviewable_type)
        page.has_css?(
          ".unknown-reviewables ul li",
          text:
            I18n.t("js.review.unknown.reviewable_unknown_source", reviewableType: reviewable_type),
        )
      end

      def click_claim_reviewable
        find(".reviewable-claimed-topic .claim").click
      end

      def click_unclaim_reviewable
        find(".reviewable-claimed-topic .unclaim").click
      end

      private

      def reviewable_action_dropdown
        @reviewable_action_dropdown ||=
          PageObjects::Components::SelectKit.new(REVIEWABLE_ACTION_DROPDOWN)
      end
    end
  end
end
