# frozen_string_literal: true

module PageObjects
  module Pages
    class AccountActivation < PageObjects::Pages::Base
      def editable?
        has_css?(".not-activated-modal .activation-controls button.edit-email")
      end

      def change_email(email)
        find(".activation-controls button.edit-email").click
        find(".activate-new-email").fill_in(with: email)
        find(".d-modal__footer .btn-primary").click
      end

      def activate_from(activation_link)
        visit(activation_link)
        find(".activate-account-button").click
      end

      def approval_required?
        has_css?(
          ".account-activated",
          text: I18n.t("js.user.activate_account.approval_required"),
        )
      end
    end
  end
end
