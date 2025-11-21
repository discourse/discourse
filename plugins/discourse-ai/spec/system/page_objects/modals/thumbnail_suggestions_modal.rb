# frozen_string_literal: true

module PageObjects
  module Modals
    class ThumbnailSuggestionsModal < PageObjects::Modals::Base
      def visible?
        page.has_css?(".thumbnail-suggestions-modal", wait: 5)
      end

      def has_thumbnails?
        page.has_css?(".ai-thumbnail-suggestions .thumbnail-suggestion-item")
      end

      def loading?
        page.has_css?(".thumbnail-suggestions-modal .loading-container")
      end

      def select_thumbnail(index)
        find(".ai-thumbnail-suggestions .thumbnail-suggestion-item:nth-child(#{index + 1})").click
        self
      end

      def click_save
        find(".d-modal__footer button.create").click
      end

      def click_try_again
        find(".d-modal__footer button.regenerate").click
      end

      def try_again_disabled?
        find(".d-modal__footer button.regenerate")[:disabled] == "true"
      end

      def save_disabled?
        find(".d-modal__footer button.create")[:disabled] == "true"
      end
    end
  end
end
