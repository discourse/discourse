# frozen_string_literal: true

module PageObjects
  module Modals
    class PrivateMessageInvite < PageObjects::Modals::Base
      MODAL_SELECTOR = ".add-pm-participants"
      BODY_SELECTOR = ".invite.modal-panel"

      def select_invitee(user)
        select_kit = PageObjects::Components::SelectKit.new(".invite-user-input")
        select_kit.expand
        select_kit.search(user.username)
        select_kit.select_row_by_value(user.username)
      end

      def has_invitee_already_exists_error?
        body.find(".alert-error").has_text?(I18n.t("topic_invite.user_exists"))
      end

      def click_primary_button
        body.find(".btn-primary").click
      end

      def has_successful_invite_message?
        has_content?(I18n.t("js.topic.invite_private.success"))
      end
    end
  end
end
