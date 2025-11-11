# frozen_string_literal: true
module PageObjects
  module Modals
    class UpsertHyperlink < PageObjects::Modals::Base
      BODY_SELECTOR = ".upsert-hyperlink-modal"
      MODAL_SELECTOR = ".upsert-hyperlink-modal"
      LINK_TEXT_SELECTOR = ".d-modal__body input.link-text"
      LINK_URL_SELECTOR = ".d-modal__body input.link-url"

      def fill_in_link_text(text)
        find(LINK_TEXT_SELECTOR).fill_in(with: text)
      end

      def send_enter_link_text
        find(LINK_TEXT_SELECTOR).send_keys(:enter)
      end

      def fill_in_link_url(url)
        find(LINK_URL_SELECTOR).fill_in(with: url)
      end

      def link_text_value
        find(LINK_TEXT_SELECTOR).value
      end

      def link_url_value
        find(LINK_URL_SELECTOR).value
      end
    end
  end
end
