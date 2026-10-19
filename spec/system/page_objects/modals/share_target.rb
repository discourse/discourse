# frozen_string_literal: true

module PageObjects
  module Modals
    class ShareTarget < PageObjects::Modals::Base
      def initialize
        super(modal_selector: ".share-target-modal")
      end

      def click_new_topic
        footer.locator(".share-target-modal__new-topic").filter(visible: true).click
      end

      def has_preview_text?(text)
        contain_text([browser_text_pattern(text)], useInnerText: true).matches?(
          body.locator(".share-target-modal__preview-text").filter(visible: true),
        )
      end
    end
  end
end
