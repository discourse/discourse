# frozen_string_literal: true

module PageObjects
  module Modals
    class AdminIncomingEmailDetailsModal < PageObjects::Modals::Base
      MODAL_SELECTOR = ".admin-incoming-email-modal"

      def has_no_error?
        has_no_css?(".admin-incoming-email-modal__error")
      end

      def has_error_message?(message)
        has_css?(".admin-incoming-email-modal__error-message", text: message)
      end

      def has_error_description?(description)
        has_css?(".admin-incoming-email-modal__error-description", text: description)
      end
    end
  end
end
