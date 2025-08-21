# frozen_string_literal: true

module PageObjects
  module Pages
    class UserActivityDrafts < PageObjects::Pages::Base
      def visit(user)
        page.visit("/u/#{user.username_lower}/activity/drafts")
        # Wait for page to load
        has_css?("body.drafts")
        self
      end

      def has_draft?(draft_content)
        has_content?(draft_content)
      end

      def has_no_draft?(draft_content)
        has_no_content?(draft_content)
      end

      def has_drafts?
        has_css?(".user-stream-item")
      end

      def has_no_drafts?
        has_no_css?(".user-stream-item")
      end

      def has_clear_all_drafts_button?
        has_css?(".remove-all-drafts")
      end

      def has_no_clear_all_drafts_button?
        has_no_css?(".remove-all-drafts")
      end

      def click_clear_all_drafts
        find(".remove-all-drafts").click
        self
      end

      def confirm_dialog
        find(".dialog-footer .btn-danger").click
        self
      end

      def remove_first_draft
        first(".user-stream-item .remove-draft").click
        self
      end
    end
  end
end
