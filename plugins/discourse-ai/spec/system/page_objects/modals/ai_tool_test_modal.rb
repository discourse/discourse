# frozen_string_literal: true

module PageObjects
  module Modals
    class AiToolTest < PageObjects::Modals::Base
      BODY_SELECTOR = ".ai-tool-test-modal__body"
      MODAL_SELECTOR = ".ai-tool-test-modal"

      def base_currency=(value)
        body.fill_in("base_currency", with: value)
      end

      def target_currency=(value)
        body.fill_in("target_currency", with: value)
      end

      def amount=(value)
        body.fill_in("amount", with: value)
      end

      def run_test
        click_primary_button
      end
    end
  end
end
