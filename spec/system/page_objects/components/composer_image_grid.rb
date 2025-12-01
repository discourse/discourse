# frozen_string_literal: true

module PageObjects
  module Components
    class ComposerImageGrid < PageObjects::Components::Base
      def initialize(rich_editor)
        @rich_editor = rich_editor
      end

      def add_image_to_grid
        page.find(".composer-image-toolbar__add-to-grid").click
        self
      end

      def move_image_outside_grid
        page.find(".composer-image-toolbar__move-outside-grid").click
        self
      end

      def select_first_grid_image
        @rich_editor.all(".composer-image-grid .composer-image-node img").first.click
        self
      end

      def has_add_to_grid_toolbar?
        page.has_css?("[data-identifier='composer-image-toolbar']") &&
          page.has_css?(".composer-image-toolbar__add-to-grid") &&
          page.has_no_css?(".composer-image-toolbar__move-outside-grid")
      end

      def has_move_outside_grid_toolbar?
        page.has_css?("[data-identifier='composer-image-toolbar']") &&
          page.has_css?(".composer-image-toolbar__move-outside-grid") &&
          page.has_no_css?(".composer-image-toolbar__add-to-grid")
      end

      def has_images?(count)
        @rich_editor.has_css?(".composer-image-node img", count: count)
      end

      def has_grid_images?(count)
        @rich_editor.has_css?(".composer-image-grid .composer-image-node img", count: count)
      end

      def has_no_grid_images?
        @rich_editor.has_no_css?(".composer-image-grid .composer-image-node img")
      end

      def has_single_grid_with_images?(count)
        @rich_editor.has_css?(".composer-image-grid", count: 1) &&
          @rich_editor.has_css?(".composer-image-grid .composer-image-node img", count: count) &&
          @rich_editor.has_no_css?(".composer-image-grid .composer-image-grid")
      end
    end
  end
end
