# frozen_string_literal: true

module PageObjects
  module Modals
    class AiArtifactBuilder < PageObjects::Modals::Base
      MODAL_SELECTOR = ".ai-artifact-builder-modal"

      def fill_in_artifact(name:, html:)
        form.field("name").fill_in(name)
        form.field("html").fill_in(html)
        self
      end

      def submit
        form.submit
      end

      def has_field_value?(field, value)
        form.field(field).has_value?(value)
      end

      private

      def form
        PageObjects::Components::FormKit.new(MODAL_SELECTOR)
      end
    end
  end
end
