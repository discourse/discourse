# frozen_string_literal: true

module PageObjects
  module Components
    class Toasts < PageObjects::Components::Base
      def has_default?(message)
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(message)],
          useInnerText: true,
        ).matches?(browser_root.locator(".fk-d-default-toast").filter(visible: true))
      end

      def has_success?(message)
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(message)],
          useInnerText: true,
        ).matches?(browser_root.locator(".fk-d-default-toast.-success").filter(visible: true))
      end

      def close_button
        browser_root.locator(".fk-d-default-toast__close-container .btn").filter(visible: true)
      end

      def has_warning?(message)
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(message)],
          useInnerText: true,
        ).matches?(browser_root.locator(".fk-d-default-toast.-warning").filter(visible: true))
      end

      def has_info?(message)
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(message)],
          useInnerText: true,
        ).matches?(browser_root.locator(".fk-d-default-toast.-info").filter(visible: true))
      end

      def has_error?(message)
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(message)],
          useInnerText: true,
        ).matches?(browser_root.locator(".fk-d-default-toast.-error").filter(visible: true))
      end

      def has_no_message?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".fk-d-default-toast__message").filter(visible: true),
        )
      end
    end
  end
end
