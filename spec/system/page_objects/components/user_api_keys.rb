# frozen_string_literal: true

module PageObjects
  module Components
    class UserApiKeys < PageObjects::Components::Base
      ACTION_BUTTON = ".user-api-key__actions .btn"

      def has_api_key?
        page.has_css?(".user-api-key")
      end

      def has_no_revoke_button?
        page.has_no_css?(ACTION_BUTTON)
      end

      def has_revoke_button?
        page.has_css?(ACTION_BUTTON, text: I18n.t("js.user.revoke_access"))
      end

      def has_undo_revoke_button?
        page.has_css?(ACTION_BUTTON, text: I18n.t("js.user.undo_revoke_access"))
      end

      def toggle_revoke
        page.find(ACTION_BUTTON).click
        self
      end
    end
  end
end
