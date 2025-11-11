# frozen_string_literal: true

module PageObjects
  module Modals
    class DiffModal < PageObjects::Modals::Base
      def visible?
        page.has_css?(".composer-ai-helper-modal", wait: 5)
      end

      def confirm_changes
        find(".d-modal__footer button.confirm", wait: 5).click
      end

      def discard_changes
        find(".d-modal__footer button.discard", wait: 5).click
      end

      def old_value
        find(".composer-ai-helper-modal__old-value").text
      end

      def new_value
        find(".composer-ai-helper-modal__new-value").text
      end

      def has_diff?(old_value, new_value)
        has_css?(".inline-diff ins", text: new_value) &&
          has_css?(".inline-diff del", text: old_value)
      end
    end
  end
end
