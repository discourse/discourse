# frozen_string_literal: true

module PageObjects
  module Pages
    class RefreshedReview < PageObjects::Pages::Base
      REVIEWABLE_ACTION_DROPDOWN = ".reviewable-action-dropdown"

      def visit_reviewable(reviewable)
        page.visit("/review/#{reviewable.id}")
        self
      end

      def click_timeline_tab
        find(".action-list li.timeline").click
      end

      def click_insights_tab
        find(".action-list li.insights").click
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

      def has_reviewable_with_rejected_status?(reviewable)
        within(reviewable_by_id(reviewable.id)) { page.has_css?(".review-item__status.--rejected") }
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

      private

      def reviewable_by_id(id)
        find(".review-item[data-reviewable-id=\"#{id}\"]")
      end

      def reviewable_action_dropdown
        @reviewable_action_dropdown ||=
          PageObjects::Components::SelectKit.new(REVIEWABLE_ACTION_DROPDOWN)
      end
    end
  end
end
