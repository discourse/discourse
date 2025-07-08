# frozen_string_literal: true

module PageObjects
  module Modals
    class PostHistory < PageObjects::Modals::Base
      MODAL_SELECTOR = ".history-modal"

      def click_previous_revision
        footer.find("button.previous-revision").click
        self
      end

      def previous_locale
        body.find(".revision__locale .revision-content:nth-child(1)")
      end

      def current_locale
        body.find(".revision__locale .revision-content:nth-child(2)")
      end

      def current_revision
        revision_numbers.find("strong:nth-child(3)")
      end

      private

      def revision_numbers
        footer.find("#revision-numbers")
      end
    end
  end
end
