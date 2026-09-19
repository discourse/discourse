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

      def scroll_grid_to_editor_middle(index:)
        grid = @rich_editor.all(".composer-image-grid")[index]

        grid.execute_script(<<~JS)
          const editor = this.closest(".ProseMirror");
          const editorRect = editor.getBoundingClientRect();
          const gridRect = this.getBoundingClientRect();
          editor.scrollTop +=
            gridRect.top -
            editorRect.top +
            (gridRect.height - editor.clientHeight) / 2;
        JS

        self
      end

      def control_positions(index:)
        grid = @rich_editor.all(".composer-image-grid")[index]

        grid.evaluate_script(<<~JS)
          (() => {
            const editor = this.closest(".ProseMirror").getBoundingClientRect();
            const grid = this.getBoundingClientRect();
            const mode = this.querySelector(".composer-image-gallery__mode-buttons").getBoundingClientRect();
            const removeButton = this.querySelector(".composer-image-grid__remove-btn");
            const remove = removeButton.getBoundingClientRect();
            const removeLabelRange = document.createRange();
            removeLabelRange.selectNodeContents(removeButton.querySelector("span"));

            return {
              editorTop: editor.top,
              editorBottom: editor.bottom,
              gridTop: grid.top,
              gridBottom: grid.bottom,
              modeTop: mode.top,
              modeBottom: mode.bottom,
              removeTop: remove.top,
              removeBottom: remove.bottom,
              removeLabelLineCount: removeLabelRange.getClientRects().length,
            };
          })()
        JS
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

      def has_grids?(count:)
        @rich_editor.has_css?(".composer-image-grid", count: count)
      end

      def has_no_grid_images?
        @rich_editor.has_no_css?(".composer-image-grid .composer-image-node img")
      end

      def has_single_grid_with_images?(count)
        @rich_editor.has_css?(".composer-image-grid", count: 1) &&
          @rich_editor.has_css?(".composer-image-grid .composer-image-node img", count: count) &&
          @rich_editor.has_no_css?(".composer-image-grid .composer-image-grid")
      end

      def has_mode_select?
        @rich_editor.has_css?(".composer-image-gallery__mode-buttons")
      end

      def has_mode_selects?(count:)
        @rich_editor.has_css?(".composer-image-gallery__mode-buttons", count: count)
      end

      def select_mode(mode)
        @rich_editor.find(".composer-image-gallery__mode-btn[data-mode='#{mode.downcase}']").click
        self
      end

      def has_selected_mode?(value)
        @rich_editor.has_css?(".composer-image-gallery__mode-btn[data-mode='#{value}'].is-active")
      end

      def mode_value
        @rich_editor.find(".composer-image-gallery")["data-mode"]
      end
    end
  end
end
