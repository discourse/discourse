# frozen_string_literal: true

module PageObjects
  module Modals
    class AdminIncomingEmailDetailsModal < PageObjects::Modals::Base
      MODAL_SELECTOR = ".admin-incoming-email-modal"

      def has_no_error?
        have_count(0).matches?(
          browser_root.locator(".admin-incoming-email-modal__error").filter(visible: true),
        )
      end

      def has_error_message?(message)
        contain_text([browser_text_pattern(message)], useInnerText: true).matches?(
          browser_root.locator(".admin-incoming-email-modal__error-message").filter(visible: true),
        )
      end

      def has_error_description?(description)
        contain_text([browser_text_pattern(description)], useInnerText: true).matches?(
          browser_root.locator(".admin-incoming-email-modal__error-description").filter(
            visible: true,
          ),
        )
      end
    end
  end
end
