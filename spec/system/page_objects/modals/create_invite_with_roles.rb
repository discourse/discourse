# frozen_string_literal: true

module PageObjects
  module Modals
    class CreateInviteWithRoles < PageObjects::Modals::Base
      MODAL_SELECTOR = ".create-invite-with-roles-modal"

      def modal
        find(MODAL_SELECTOR)
      end

      def open?
        has_css?(MODAL_SELECTOR)
      end

      def closed?
        has_no_css?(MODAL_SELECTOR)
      end

      def form
        PageObjects::Components::FormKit.new("#{MODAL_SELECTOR} .form-kit")
      end

      def has_role_toggle?
        within(modal) { has_css?(".create-invite-with-roles-modal__role-toggle") }
      end

      def has_no_role_toggle?
        within(modal) { has_no_css?(".create-invite-with-roles-modal__role-toggle") }
      end

      def selected_role
        within(modal) do
          find(".create-invite-with-roles-modal__role-toggle input:checked", visible: false)[:value]
        end
      end

      def select_role(role)
        within(modal) do
          find(
            ".create-invite-with-roles-modal__role-toggle input[value='#{role}']",
            visible: false,
          ).ancestor("label").click
        end
      end

      def role_option_disabled?(role)
        within(modal) do
          find(
            ".create-invite-with-roles-modal__role-toggle input[value='#{role}']",
            visible: false,
          ).disabled?
        end
      end

      def select_delivery(delivery)
        within(modal) do
          find(
            ".create-invite-with-roles-modal__delivery input[value='#{delivery}']",
            visible: false,
          ).ancestor("label").click
        end
      end

      def save_button
        within(modal) { find(".save-invite") }
      end

      def toggle_advanced_options
        within(modal) { find(".toggle-advanced").click }
      end

      def edit_button
        within(modal) { find(".edit-invite") }
      end

      def cancel_button
        within(modal) { find(".cancel-button") }
      end

      def invite_link_input
        within(modal) { find("input.invite-link") }
      end

      def has_summary?
        within(modal) { has_css?(".create-invite-with-roles-modal__summary") }
      end

      def has_sent_to_message?(email)
        within(modal) { has_css?(".create-invite-with-roles-modal__sent-to", text: email) }
      end

      def has_email_sent_confirmation?(email)
        within(modal) { has_css?(".create-invite-with-roles-modal__email-sent", text: email) }
      end
    end
  end
end
