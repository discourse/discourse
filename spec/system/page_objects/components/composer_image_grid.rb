# frozen_string_literal: true

module PageObjects
  module Components
    class ComposerImageGrid < PageObjects::Components::Base
      def initialize(rich_editor)
        @rich_editor = rich_editor
      end

      def add_image_to_grid
        browser_root.locator(".composer-image-toolbar__add-to-grid").filter(visible: true).click
        self
      end

      def move_image_outside_grid
        browser_root
          .locator(".composer-image-toolbar__move-outside-grid")
          .filter(visible: true)
          .click
        self
      end

      def scroll_grid_to_editor_middle(index:)
        grid =
          @rich_editor
            .locator(".composer-image-grid")
            .filter(visible: true)
            .tap { |elements| elements.first.wait_for(state: "visible") }
            .all[
            index
          ]

        grid.evaluate("(element, args) => (function() { #{<<~JS} }).apply(element, args)", arg: [])
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
        grid =
          @rich_editor
            .locator(".composer-image-grid")
            .filter(visible: true)
            .tap { |elements| elements.first.wait_for(state: "visible") }
            .all[
            index
          ]

        grid.evaluate(
          "(element, args) => (function() { return #{<<~JS} }).apply(element, args)",
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
          arg: [],
        )
      end

      def select_first_grid_image
        @rich_editor
          .locator(".composer-image-grid .composer-image-node img")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all
          .first
          .click
        self
      end

      def has_add_to_grid_toolbar?
        have_count(0).does_not_match?(
          browser_root.locator("[data-identifier='composer-image-toolbar']").filter(visible: true),
        ) &&
          have_count(0).does_not_match?(
            browser_root.locator(".composer-image-toolbar__add-to-grid").filter(visible: true),
          ) &&
          have_count(0).matches?(
            browser_root.locator(".composer-image-toolbar__move-outside-grid").filter(
              visible: true,
            ),
          )
      end

      def has_move_outside_grid_toolbar?
        have_count(0).does_not_match?(
          browser_root.locator("[data-identifier='composer-image-toolbar']").filter(visible: true),
        ) &&
          have_count(0).does_not_match?(
            browser_root.locator(".composer-image-toolbar__move-outside-grid").filter(
              visible: true,
            ),
          ) &&
          have_count(0).matches?(
            browser_root.locator(".composer-image-toolbar__add-to-grid").filter(visible: true),
          )
      end

      def has_images?(count)
        have_count(count).matches?(
          @rich_editor.locator(".composer-image-node img").filter(visible: true),
        )
      end

      def has_grid_images?(count)
        have_count(count).matches?(
          @rich_editor.locator(".composer-image-grid .composer-image-node img").filter(
            visible: true,
          ),
        )
      end

      def has_grids?(count:)
        have_count(count).matches?(
          @rich_editor.locator(".composer-image-grid").filter(visible: true),
        )
      end

      def has_no_grid_images?
        have_count(0).matches?(
          @rich_editor
            .tap do |parent|
              parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
            end
            .locator(".composer-image-grid .composer-image-node img")
            .filter(visible: true),
        )
      end

      def has_single_grid_with_images?(count)
        have_count(1).matches?(
          @rich_editor.locator(".composer-image-grid").filter(visible: true),
        ) &&
          have_count(count).matches?(
            @rich_editor.locator(".composer-image-grid .composer-image-node img").filter(
              visible: true,
            ),
          ) &&
          have_count(0).matches?(
            @rich_editor
              .tap do |parent|
                parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
              end
              .locator(".composer-image-grid .composer-image-grid")
              .filter(visible: true),
          )
      end

      def has_mode_select?
        have_count(0).does_not_match?(
          @rich_editor.locator(".composer-image-gallery__mode-buttons").filter(visible: true),
        )
      end

      def has_mode_selects?(count:)
        have_count(count).matches?(
          @rich_editor.locator(".composer-image-gallery__mode-buttons").filter(visible: true),
        )
      end

      def select_mode(mode)
        @rich_editor
          .locator(".composer-image-gallery__mode-btn[data-mode='#{mode.downcase}']")
          .filter(visible: true)
          .click
        self
      end

      def has_selected_mode?(value)
        have_count(0).does_not_match?(
          @rich_editor.locator(
            ".composer-image-gallery__mode-btn[data-mode='#{value}'].is-active",
          ).filter(visible: true),
        )
      end

      def mode_value
        @rich_editor
          .locator(".composer-image-gallery")
          .filter(visible: true)
          .get_attribute("data-mode")
      end
    end
  end
end
