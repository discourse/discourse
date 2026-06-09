# frozen_string_literal: true

module PageObjects
  module Components
    class AiArtifact < PageObjects::Components::Base
      COMPOSER_PREVIEW_SELECTOR = ".d-editor-preview"

      def initialize(post: nil)
        @scope = post ? "[data-post-number='#{post.post_number}']" : COMPOSER_PREVIEW_SELECTOR
      end

      def click_run
        within(@scope) { find(".ai-artifact__click-to-run button").click }
      end

      def click_edit
        within(@scope) { find(".ai-artifact__edit-button", wait: 5).click }
      end

      def has_rendered_body?(text)
        within(@scope) do
          within_frame(find("iframe")) do
            within_frame(find("iframe")) { has_css?("body", text: text) }
          end
        end
      end
    end
  end
end
