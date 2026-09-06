# frozen_string_literal: true

module PageObjects
  module Modals
    class ShareTarget < PageObjects::Modals::Base
      def initialize
        super(modal_selector: ".share-target-modal")
      end

      def click_new_topic
        footer.find(".share-target-modal__new-topic").click
      end

      def has_preview_text?(text)
        body.has_css?(".share-target-modal__preview-text", text: text)
      end
    end
  end
end
