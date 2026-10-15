# frozen_string_literal: true

module PageObjects
  module Pages
    class UserActivityDrafts < PageObjects::Pages::Base
      def visit(user)
        browser_page
          .goto("/u/#{user.username_lower}/activity/drafts")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def has_drafts?(count: 1)
        PlaywrightMatchers.have_count(count).matches?(
          browser_root.locator(".post-list-item").filter(visible: true),
        )
      end

      def has_no_drafts?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".post-list__empty-text").filter(visible: true),
        )
      end

      def has_bulk_select_checkboxes?
        PlaywrightMatchers.be_attached.matches?(
          browser_root.locator(".bulk-select-checkbox").filter(visible: true).nth(1 - 1),
        )
      end

      def has_no_bulk_select_checkboxes?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".bulk-select-checkbox").filter(visible: true),
        )
      end

      def has_bulk_controls?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".post-list-bulk-controls").filter(visible: true),
        )
      end

      def has_no_bulk_controls?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".post-list-bulk-controls").filter(visible: true),
        )
      end

      def select_draft(index = 0)
        browser_root
          .locator(".post-list-item:nth-of-type(#{index + 1}) .bulk-select-checkbox")
          .filter(visible: true)
          .click
        self
      end

      def select_all_drafts
        click_bulk_select_all
        self
      end

      def clear_all_selections
        click_bulk_clear_all
        self
      end

      def click_bulk_select_all
        browser_root.locator(".bulk-select-all").filter(visible: true).click
        self
      end

      def click_bulk_clear_all
        browser_root.locator(".bulk-clear-all").filter(visible: true).click
        self
      end

      def click_bulk_actions
        browser_root
          .locator("button")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern("Bulk actions"))
          .click
        self
      end

      def click_bulk_delete
        click_bulk_actions
        browser_root.locator(".dropdown-menu .btn-danger").filter(visible: true).click
        self
      end

      def selected_count_text
        browser_root
          .locator(".post-list-bulk-controls__count")
          .filter(visible: true)
          .inner_text
          .strip
      end

      def has_selected_count?(count)
        if count == 1
          PlaywrightMatchers.contain_text(
            browser_text_pattern("#{count} post selected"),
            useInnerText: true,
          ).matches?(browser_content)
        else
          PlaywrightMatchers.contain_text(
            browser_text_pattern("#{count} posts selected"),
            useInnerText: true,
          ).matches?(browser_content)
        end
      end

      def has_draft_selected?(index = 0)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            ".post-list-item:nth-of-type(#{index + 1}) .post-list-item--selected",
          ).filter(visible: true),
        )
      end

      def has_no_draft_selected?(index = 0)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(
            ".post-list-item:nth-of-type(#{index + 1}) .post-list-item--selected",
          ).filter(visible: true),
        )
      end

      def has_checkbox_checked?(index = 0)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            ".post-list-item:nth-of-type(#{index + 1}) .bulk-select-checkbox:checked",
          ).filter(visible: true),
        )
      end

      def has_checkbox_unchecked?(index = 0)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(
            ".post-list-item:nth-of-type(#{index + 1}) .bulk-select-checkbox:checked",
          ).filter(visible: true),
        )
      end
    end
  end
end
