# frozen_string_literal: true
module PageObjects
  module Modals
    class UpsertHyperlink < PageObjects::Modals::Base
      BODY_SELECTOR = ".upsert-hyperlink-modal"
      MODAL_SELECTOR = ".upsert-hyperlink-modal"
      LINK_TEXT_SELECTOR = ".d-modal__body input.link-text"
      LINK_URL_SELECTOR = ".d-modal__body input.link-url"

      def fill_in_link_text(text)
        browser_root.locator(LINK_TEXT_SELECTOR).filter(visible: true).fill(text)
      end

      def send_enter_link_text
        browser_root.locator(LINK_TEXT_SELECTOR).filter(visible: true).press("Enter")
      end

      def fill_in_link_url(url)
        browser_root.locator(LINK_URL_SELECTOR).filter(visible: true).fill(url)
      end

      def link_text_value
        browser_root.locator(LINK_TEXT_SELECTOR).filter(visible: true).input_value
      end

      def link_url_value
        browser_root.locator(LINK_URL_SELECTOR).filter(visible: true).input_value
      end

      def has_link_text_field?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(LINK_TEXT_SELECTOR).filter(visible: true),
        )
      end

      def has_no_link_text_field?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(LINK_TEXT_SELECTOR).filter(visible: true),
        )
      end
    end
  end
end
