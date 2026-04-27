# frozen_string_literal: true

module PageObjects
  module Components
    class AiArtifactComposerToolbar < PageObjects::Components::Base
      TRIGGER_SELECTOR = ".toolbar-menu__options-trigger"
      INSERT_BUTTON_SELECTOR = "button[data-name='ai-artifact']"

      def open_insert_artifact
        find(TRIGGER_SELECTOR).click
        find(INSERT_BUTTON_SELECTOR).click
      end

      def has_no_insert_artifact_option?
        find(TRIGGER_SELECTOR).click
        page.has_no_css?(INSERT_BUTTON_SELECTOR)
      end
    end
  end
end
