# frozen_string_literal: true

module PageObjects
  module Pages
    class Review < PageObjects::Pages::Base
      REVIEWABLE_ACTION_DROPDOWN = ".reviewable-action-dropdown"

      def visit_reviewable(reviewable)
        browser_page
          .goto("/review/#{reviewable.id}")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      # Reaching a reviewable through the user menu keeps the app running, which
      # is the only way to exercise the state a reviewable item carries over from
      # the previously displayed one. `visit_reviewable` always starts afresh.
      def visit_reviewable_from_user_menu(reviewable)
        PageObjects::Components::UserMenu.new.open.click_review_queue_tab.click_reviewable(
          reviewable,
        )
        reviewable_by_id(reviewable.id)
        self
      end

      def select_bundled_action(reviewable, value, bundle_index: nil)
        within_browser(reviewable_by_id(reviewable.id)) do
          dropdown =
            if bundle_index
              PageObjects::Components::SelectKit.new(
                "#{REVIEWABLE_ACTION_DROPDOWN}:nth-of-type(#{bundle_index})",
              )
            else
              reviewable_action_dropdown
            end
          dropdown.select_row_by_value(value)
        end
      end

      def select_action(reviewable, value)
        within_browser(reviewable_by_id(reviewable.id)) do
          browser_root.locator(".reviewable-action.#{value.dasherize}").filter(visible: true).click
        end
      end

      # Pass confirm: false for reviewables that require a rejection reason, as
      # those open a modal instead of the confirmation dialog.
      def delete_user_from_reviewable(reviewable, action, confirm: true)
        select_bundled_action(reviewable, action, bundle_index: 1)
        PageObjects::Components::Dialog.new.click_danger if confirm
      end

      def has_reviewable_action_dropdown?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(REVIEWABLE_ACTION_DROPDOWN).filter(visible: true),
        )
      end

      def has_no_reviewable_action_dropdown?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(REVIEWABLE_ACTION_DROPDOWN).filter(visible: true),
        )
      end

      def has_no_reviewable_actions?(reviewable)
        within_browser(reviewable_by_id(reviewable.id)) do
          PlaywrightMatchers.have_count(0).matches?(
            browser_root.locator(".reviewable-action, #{REVIEWABLE_ACTION_DROPDOWN}").filter(
              visible: true,
            ),
          )
        end
      end

      def has_reviewable_items?(count:)
        PlaywrightMatchers.have_count(count).matches?(
          browser_root.locator(".review-item").filter(visible: true),
        )
      end

      def has_reviewable_with_rejection_reason?(reviewable, rejection_reason)
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(rejection_reason)],
          useInnerText: true,
        ).matches?(
          reviewable_by_id(reviewable.id).locator(
            ".reviewable-user-details.reject-reason .value",
          ).filter(visible: true),
        )
      end

      def has_scrub_button?(reviewable)
        within_browser(reviewable_by_id(reviewable.id)) do
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root.locator(".user-scrub").filter(visible: true),
          )
        end
      end

      def click_scrub_user_button
        browser_root.locator(".user-scrub").filter(visible: true).click
      end

      def has_reviewable_with_scrubbed_by?(reviewable, scrubbed_by)
        within_browser(reviewable_by_id(reviewable.id)) do
          PlaywrightMatchers.contain_text(
            [browser_text_pattern(scrubbed_by)],
            useInnerText: true,
          ).matches?(
            browser_root.locator(".reviewable-user-details.scrubbed-by .value").filter(
              visible: true,
            ),
          )
        end
      end

      def has_reviewable_with_scrubbed_reason?(reviewable, scrubbed_reason)
        within_browser(reviewable_by_id(reviewable.id)) do
          PlaywrightMatchers.contain_text(
            [browser_text_pattern(scrubbed_reason)],
            useInnerText: true,
          ).matches?(
            browser_root.locator(".reviewable-user-details.scrubbed-reason .value").filter(
              visible: true,
            ),
          )
        end
      end

      def has_reviewable_with_scrubbed_at?(reviewable, scrubbed_at)
        within_browser(reviewable_by_id(reviewable.id)) do
          PlaywrightMatchers.contain_text(
            [browser_text_pattern(scrubbed_at)],
            useInnerText: true,
          ).matches?(
            browser_root.locator(".reviewable-user-details.scrubbed-at .value").filter(
              visible: true,
            ),
          )
        end
      end

      def has_no_error_dialog_visible?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator("dialog-container .dialog-content").filter(visible: true),
        )
      end

      def click_ignore_all_unknown_reviewables
        browser_root.locator(".unknown-reviewables__options button").filter(visible: true).click
        browser_root.locator(".dialog-footer .btn-danger").filter(visible: true).click
      end

      def has_information_about_unknown_reviewables_visible?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".unknown-reviewables").filter(visible: true),
        )
      end

      def has_no_information_about_unknown_reviewables_visible?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".unknown-reviewables").filter(visible: true),
        )
      end

      def has_listing_for_unknown_reviewables_plugin?(reviewable_type, plugin_name)
        PlaywrightMatchers.contain_text(
          [
            browser_text_pattern(
              I18n.t(
                "js.review.unknown.reviewable_known_source",
                reviewableType: reviewable_type,
                pluginName: plugin_name,
              ),
            ),
          ],
          useInnerText: true,
        ).matches?(browser_root.locator(".unknown-reviewables ul li").filter(visible: true))
      end

      def has_listing_for_unknown_reviewables_unknown_source?(reviewable_type)
        PlaywrightMatchers.contain_text(
          [
            browser_text_pattern(
              I18n.t(
                "js.review.unknown.reviewable_unknown_source",
                reviewableType: reviewable_type,
              ),
            ),
          ],
          useInnerText: true,
        ).matches?(browser_root.locator(".unknown-reviewables ul li").filter(visible: true))
      end

      def click_claim_reviewable
        browser_root.locator(".reviewable-claimed-topic .claim").filter(visible: true).click
      end

      def click_unclaim_reviewable
        browser_root.locator(".reviewable-claimed-topic .unclaim").filter(visible: true).click
      end

      def has_context_question?(reviewable, text)
        within_browser(reviewable_by_id(reviewable.id)) do
          PlaywrightMatchers.contain_text(
            [browser_text_pattern(text)],
            useInnerText: true,
          ).matches?(browser_root.locator(".review-item__aside-title").filter(visible: true))
        end
      end

      def has_no_context_question?(reviewable, text)
        within_browser(reviewable_by_id(reviewable.id)) do
          PlaywrightMatchers.contain_text(
            [browser_text_pattern(text)],
            useInnerText: true,
          ).does_not_match?(browser_root.locator(".review-item__aside-title").filter(visible: true))
        end
      end

      def flag_reason_component
        PageObjects::Components::Review::FlagReason.new
      end

      def topic_link_component
        PageObjects::Components::Review::TopicLink.new
      end

      def has_history_items?(count:)
        PlaywrightMatchers.have_count(count).matches?(
          browser_root.locator(".timeline-event").filter(visible: true),
        )
      end

      def has_claimed_history_item?(user)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".timeline-event__icon .d-icon-user-plus").filter(visible: true),
        ) &&
          PlaywrightMatchers.contain_text(
            browser_text_pattern("Claimed by"),
            useInnerText: true,
          ).matches?(browser_content)
      end

      def has_unclaimed_history_item?(user)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".timeline-event__icon .d-icon-user-xmark").filter(visible: true),
        ) &&
          PlaywrightMatchers.contain_text(
            browser_text_pattern("Unclaimed by"),
            useInnerText: true,
          ).matches?(browser_content)
      end

      def has_created_at_history_item?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".timeline-event__icon .d-icon-pen-to-square").filter(visible: true),
        ) &&
          PlaywrightMatchers.contain_text(
            browser_text_pattern("Post created by"),
            useInnerText: true,
          ).matches?(browser_content)
      end

      def click_timeline_tab
        browser_root.locator(".action-list li.timeline").filter(visible: true).click
      end

      def click_insights_tab
        browser_root.locator(".action-list li.insights").filter(visible: true).click
      end

      def has_reviewable_with_status?(reviewable, status)
        within_browser(reviewable_by_id(reviewable.id)) do
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root.locator(".review-item__status.--#{status}").filter(visible: true),
          )
        end
      end

      def has_reviewable_with_approved_status?(reviewable)
        within_browser(reviewable_by_id(reviewable.id)) do
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root.locator(".review-item__status.--approved").filter(visible: true),
          )
        end
      end

      def has_reviewable_with_rejected_status?(reviewable)
        within_browser(reviewable_by_id(reviewable.id)) do
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root.locator(".review-item__status.--rejected").filter(visible: true),
          )
        end
      end

      def has_rejected_item_in_timeline?(reviewable)
        within_browser(reviewable_by_id(reviewable.id)) do
          PlaywrightMatchers.contain_text(
            browser_text_pattern("Rejected by"),
            useInnerText: true,
          ).matches?(browser_content)
        end
      end

      def has_reviewable_with_pending_status?(reviewable)
        within_browser(reviewable_by_id(reviewable.id)) do
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root.locator(".review-item__status.--pending").filter(visible: true),
          )
        end
      end

      def has_reviewable_with_ignored_status?(reviewable)
        within_browser(reviewable_by_id(reviewable.id)) do
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root.locator(".review-item__status.--ignored").filter(visible: true),
          )
        end
      end

      def has_approved_item_in_timeline?(reviewable)
        within_browser(reviewable_by_id(reviewable.id)) do
          PlaywrightMatchers.contain_text(
            browser_text_pattern("Approved by"),
            useInnerText: true,
          ).matches?(browser_content)
        end
      end

      def has_reviewables?(reviewables)
        reviewable_ids = reviewables.map(&:id)
        PlaywrightMatchers.have_count(reviewables.size).matches?(
          browser_root.locator(".review-item").filter(visible: true),
        ) &&
          reviewable_ids.all? do |id|
            PlaywrightMatchers.have_count(0).does_not_match?(
              browser_root.locator(".review-item[data-reviewable-id='#{id}']").filter(
                visible: true,
              ),
            )
          end
      end

      def click_approve_user_button
        browser_root.locator(".user-approve-user").filter(visible: true).click
      end

      def fill_post_content(content)
        browser_root.locator(".d-editor-input").filter(visible: true).fill(content)
      end

      def save_post_edit
        browser_root.locator(".reviewable-action.save-edit").filter(visible: true).click
      end

      def has_ip_lookup_info?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".reviewable-ip-lookup").filter(visible: true),
        )
      end

      def has_no_ip_lookup_info?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".reviewable-ip-lookup").filter(visible: true),
        )
      end

      def has_ip_location?(location)
        PlaywrightMatchers.contain_text(
          browser_text_pattern(location),
          useInnerText: true,
        ).matches?(browser_content)
      end

      def has_ip_hostname?(hostname)
        PlaywrightMatchers.contain_text(
          browser_text_pattern(hostname),
          useInnerText: true,
        ).matches?(browser_content)
      end

      def has_ip_lookup_modal?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".ip-lookup-other-accounts-modal").filter(visible: true),
        )
      end

      def has_account_in_modal?(username)
        within_browser(
          browser_root.locator(".ip-lookup-other-accounts-modal").filter(visible: true),
        ) do
          PlaywrightMatchers.contain_text(
            browser_text_pattern(username),
            useInnerText: true,
          ).matches?(browser_content)
        end
      end

      def has_other_accounts_link?(count:)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root
            .get_by_role("button")
            .and(
              browser_root.locator(
                "[id=#{I18n.t("js.ip_lookup.other_accounts_with_ip", count: count).to_s.to_json}], [name=#{I18n.t("js.ip_lookup.other_accounts_with_ip", count: count).to_s.to_json}]",
              ).or(
                browser_root.get_by_role(
                  "button",
                  name: I18n.t("js.ip_lookup.other_accounts_with_ip", count: count),
                ),
              ),
            )
            .filter(visible: true),
        )
      end

      def click_other_accounts_link
        browser_root.locator(".ip-lookup-other-accounts-link").filter(visible: true).click
      end

      def click_edit_post_button
        browser_root.locator(".reviewable-action.edit").filter(visible: true).click
      end

      private

      def reviewable_by_id(id)
        browser_root.locator(".review-item[data-reviewable-id=\"#{id}\"]").filter(visible: true)
      end

      def reviewable_action_dropdown
        @reviewable_action_dropdown ||=
          PageObjects::Components::SelectKit.new(REVIEWABLE_ACTION_DROPDOWN)
      end
    end
  end
end
