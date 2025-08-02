# frozen_string_literal: true

module PageObjects
  module Pages
    class ActivateAccount < PageObjects::Pages::Base
      def click_activate_account
        find(".activate-account-button").click
      end

      def click_continue
        find(".account-activated .continue-button").click
      end

      def has_error?
        has_css?(".alert-error")
        has_content?(I18n.t("js.user.activate_account.already_done"))
      end
    end
  end
end
