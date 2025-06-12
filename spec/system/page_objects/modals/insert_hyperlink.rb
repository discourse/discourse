# frozen_string_literal: true
module PageObjects
  module Modals
    class InsertHyperlink < PageObjects::Modals::Base
      BODY_SELECTOR = ".insert-hyperlink-modal"
      MODAL_SELECTOR = ".insert-hyperlink-modal"
      LINK_TEXT_SELECTOR = ".d-modal__body input.link-text"
      LINK_URL_SELECTOR = ".d-modal__body input.link-url"

      def fill_in_link_text(text)
        find(LINK_TEXT_SELECTOR).fill_in(with: text)
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
