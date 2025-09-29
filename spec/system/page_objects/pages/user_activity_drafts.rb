# frozen_string_literal: true

module PageObjects
  module Pages
    class UserActivityDrafts < PageObjects::Pages::Base
      def visit(user)
        page.visit("/u/#{user.username_lower}/activity/drafts")
        self
      end

      def has_drafts?(count: 1)
        page.has_css?(".post-list-item", count: count)
      end

      def has_no_drafts?
        page.has_css?(".post-list__empty-text")
      end

      def has_bulk_select_checkboxes?
        page.has_css?(".bulk-select-checkbox", minimum: 1)
      end

      def has_no_bulk_select_checkboxes?
        page.has_no_css?(".bulk-select-checkbox")
      end

      def has_bulk_controls?
        page.has_css?(".post-list-bulk-controls")
      end

      def has_no_bulk_controls?
        page.has_no_css?(".post-list-bulk-controls")
      end

      def select_draft(index = 0)
        checkboxes = page.all(".bulk-select-checkbox")
        checkboxes[index].click
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
        page.find(".bulk-select-all").click
        self
      end

      def click_bulk_clear_all
        page.find(".bulk-clear-all").click
        self
      end

      def click_bulk_actions
        page.find("button", text: "Bulk actions").click
        self
      end

      def click_bulk_delete
        click_bulk_actions
        page.find(".dropdown-menu .btn-danger").click
        self
      end

      def selected_count_text
        page.find(".post-list-bulk-controls__count").text
      end

      def has_selected_count?(count)
        if count == 1
          page.has_content?("#{count} post selected")
        else
          page.has_content?("#{count} posts selected")
        end
      end

      def has_draft_selected?(index = 0)
        drafts = page.all(".post-list-item")
        drafts[index].has_css?(".post-list-item--selected")
      end

      def has_no_draft_selected?(index = 0)
        drafts = page.all(".post-list-item")
        drafts[index].has_no_css?(".post-list-item--selected")
      end

      def has_checkbox_checked?(index = 0)
        checkboxes = page.all(".bulk-select-checkbox")
        checkboxes[index].checked?
      end

      def has_checkbox_unchecked?(index = 0)
        checkboxes = page.all(".bulk-select-checkbox")
        !checkboxes[index].checked?
      end
    end
  end
end
