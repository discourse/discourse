# frozen_string_literal: true

module PageObjects
  module Modals
    class CreateInviteWithRoles < PageObjects::Modals::Base
      MODAL_SELECTOR = ".create-invite-with-roles-modal"

      def modal
        browser_root.locator(MODAL_SELECTOR).filter(visible: true)
      end

      def open?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(MODAL_SELECTOR).filter(visible: true),
        )
      end

      def closed?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(MODAL_SELECTOR).filter(visible: true),
        )
      end

      def form
        PageObjects::Components::FormKit.new("#{MODAL_SELECTOR} .form-kit")
      end

      def has_role_toggle?
        within_browser(modal) do
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root.locator(".d-segmented-control").filter(visible: true),
          )
        end
      end

      def has_no_role_toggle?
        within_browser(modal) do
          PlaywrightMatchers.have_count(0).matches?(
            browser_root.locator(".d-segmented-control").filter(visible: true),
          )
        end
      end

      def selected_role
        within_browser(modal) do
          browser_root.locator(".d-segmented-control input:checked").evaluate(
            "(element, name) => { const value = element[name]; return value !== null && value !== undefined && value !== false && !['object', 'function'].includes(typeof value) ? value : element.getAttribute(name); }",
            arg: "value",
          )
        end
      end

      def select_role(role)
        within_browser(modal) do
          browser_root
            .locator(".d-segmented-control input[value='#{role}']")
            .locator("xpath=ancestor::*")
            .and(browser_page.locator("label"))
            .last
            .click
        end
      end

      def select_delivery(delivery)
        within_browser(modal) do
          browser_root
            .locator(".form-kit__inline-radio input[value='#{delivery}']")
            .locator("xpath=ancestor::*")
            .and(browser_page.locator("label"))
            .last
            .click
        end
      end

      def save_button
        within_browser(modal) { browser_root.locator(".save-invite").filter(visible: true) }
      end

      def toggle_advanced_options
        within_browser(modal) do
          browser_root.locator(".advanced-mode-btn").filter(visible: true).click
        end
      end

      def edit_button
        within_browser(modal) { browser_root.locator(".edit-invite").filter(visible: true) }
      end

      def cancel_button
        within_browser(modal) { browser_root.locator(".cancel-button").filter(visible: true) }
      end

      def invite_link_input
        within_browser(modal) { browser_root.locator("input.invite-link").filter(visible: true) }
      end

      def has_summary?
        within_browser(modal) do
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root.locator(".create-invite-with-roles-modal__summary").filter(visible: true),
          )
        end
      end

      def has_sent_to_message?(email)
        within_browser(modal) do
          PlaywrightMatchers.contain_text(
            [browser_text_pattern(email)],
            useInnerText: true,
          ).matches?(
            browser_root.locator(".create-invite-with-roles-modal__sent-to").filter(visible: true),
          )
        end
      end

      def has_email_sent_confirmation?(email)
        within_browser(modal) do
          PlaywrightMatchers.contain_text(
            [browser_text_pattern(email)],
            useInnerText: true,
          ).matches?(
            browser_root.locator(".create-invite-with-roles-modal__email-sent").filter(
              visible: true,
            ),
          )
        end
      end
    end
  end
end
