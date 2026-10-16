# frozen_string_literal: true

module PageObjects
  module Modals
    class PrivateMessageRemoveParticipant < PageObjects::Components::Base
      def open?
        have_count(0).does_not_match?(
          browser_root.locator("#dialog-holder .dialog-content").filter(visible: true),
        )
      end

      def closed?
        have_count(0).matches?(
          browser_root.locator("#dialog-holder .dialog-content").filter(visible: true),
        )
      end

      def body
        browser_root.locator("#dialog-holder .dialog-content .dialog-body").filter(visible: true)
      end

      def confirm_removal
        browser_root
          .locator("#dialog-holder .dialog-content .dialog-footer .btn-danger")
          .filter(visible: true)
          .click
      end

      def cancel
        browser_root
          .locator("#dialog-holder .dialog-content .dialog-footer .btn-default")
          .filter(visible: true)
          .click
      end
    end
  end
end
