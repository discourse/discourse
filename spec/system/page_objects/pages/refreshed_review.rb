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

      def select_bundled_action(reviewable, value, bundle_id = nil)
        within(reviewable_by_id(reviewable.id)) do
          if bundle_id
            dropdown_selector = "#{REVIEWABLE_ACTION_DROPDOWN}.#{bundle_id.dasherize}"
            dropdown = PageObjects::Components::SelectKit.new(dropdown_selector)
            dropdown.expand
            dropdown.select_row_by_value(value)
          else
            dropdown_count = all(REVIEWABLE_ACTION_DROPDOWN).count
            dropdown_count.times do |index|
              dropdown_selector = "#{REVIEWABLE_ACTION_DROPDOWN}:nth-of-type(#{index + 1})"
              dropdown = PageObjects::Components::SelectKit.new(dropdown_selector)
              dropdown.expand
              if dropdown.expanded_component.has_css?(
                   ".select-kit-row[data-value='#{value}']",
                   wait: 0,
                 )
                dropdown.select_row_by_value(value)
                break
              else
                dropdown.collapse
              end
            end
          end
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

      def has_rejected_item_in_timeline?(reviewable)
        within(reviewable_by_id(reviewable.id)) { page.has_text?("Rejected by") }
      end

      def has_reviewable_with_pending_status?(reviewable)
        within(reviewable_by_id(reviewable.id)) { page.has_css?(".review-item__status.--pending") }
      end

      def has_reviewable_with_approved_status?(reviewable)
        within(reviewable_by_id(reviewable.id)) { page.has_css?(".review-item__status.--approved") }
      end

      def has_approved_item_in_timeline?(reviewable)
        within(reviewable_by_id(reviewable.id)) { page.has_text?("Approved by") }
      end

      def has_reviewable_with_ignored_status?(reviewable)
        within(reviewable_by_id(reviewable.id)) { page.has_css?(".review-item__status.--ignored") }
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

      def click_edit_post_button
        find(".reviewable-action.edit").click
      end

      def click_scrub_user_button
        find(".user-scrub").click
      end

      def fill_post_content(content)
        find(".d-editor-input").fill_in(with: content)
      end

      def save_post_edit
        find(".reviewable-action.save-edit").click
      end

      def has_ip_lookup_info?
        page.has_css?(".reviewable-ip-lookup")
      end

      def has_ip_location?(location)
        page.has_text?(location)
      end

      def has_ip_hostname?(hostname)
        page.has_text?(hostname)
      end

      def has_ip_organization?(organization)
        page.has_text?(organization)
      end

      def has_other_accounts_link?(count:)
        page.has_button?(I18n.t("js.ip_lookup.other_accounts_with_ip", count: count))
      end

      def click_other_accounts_link
        find(".ip-lookup-other-accounts-link").click
      end

      def has_ip_lookup_modal?
        page.has_css?(".ip-lookup-other-accounts-modal")
      end

      def has_account_in_modal?(username)
        within(".ip-lookup-other-accounts-modal") { page.has_text?(username) }
      end

      def click_claim_reviewable
        find(".reviewable-claimed-topic .claim").click
      end

      def click_unclaim_reviewable
        find(".reviewable-claimed-topic .unclaim").click
      end

      def has_context_question?(reviewable, text)
        within(reviewable_by_id(reviewable.id)) do
          page.has_css?(".review-item__aside-title", text: text)
        end
      end

      def has_created_at_history_item?
        expect(page).to have_css(".timeline-event__icon .d-icon-pen-to-square")
        expect(page).to have_text("Post created by")
      end

      def has_claimed_history_item?(user)
        expect(page).to have_css(".timeline-event__icon .d-icon-user-plus")
        expect(page).to have_text("Claimed by")
      end

      def has_unclaimed_history_item?(user)
        expect(page).to have_css(".timeline-event__icon .d-icon-user-xmark")
        expect(page).to have_text("Unclaimed by")
      end

      def has_history_items?(count:)
        expect(page).to have_css(".timeline-event", count: count)
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
