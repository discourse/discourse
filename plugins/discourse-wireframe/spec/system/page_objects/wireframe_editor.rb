# frozen_string_literal: true

module PageObjects
  module Pages
    # Drives the wireframe editor for system tests: entering edit mode and
    # locating the live-rendered grid, its cells, and the palette so a real
    # browser drag (`drag_to`) can be performed and its result asserted.
    #
    # Selectors mirror the editor's actual DOM contracts (see the JS
    # `editor-dom-contract` module) so this page object breaks loudly if those
    # change — the same regression class the JS contract tests guard.
    class WireframeEditor < PageObjects::Pages::Base
      GRID_SELECTOR = ".d-block-layout--grid"
      EMPTY_CELL_SELECTOR = ".wireframe-grid-cell"
      PALETTE_ENTRY_SELECTOR = ".wireframe-block-tile"

      def enter
        find(".wireframe-pill").click
        has_grid?
        self
      end

      def has_grid?
        page.has_css?(GRID_SELECTOR, wait: 5)
      end

      # The grid overlay only mounts its cells once it has located the grid
      # container. If the editor→render class contract breaks, `gridElement`
      # stays null and NO empty-cell placeholders render — so this is the
      # direct system-level guard for the drop-target-registration regression.
      def has_empty_cells?
        page.has_css?(EMPTY_CELL_SELECTOR, wait: 5)
      end

      def grid
        find(GRID_SELECTOR)
      end

      def empty_cell(column:, row:)
        find("#{EMPTY_CELL_SELECTOR}[data-col='#{column}'][data-row='#{row}']")
      end

      def block(name)
        find(".#{name}")
      end

      def palette_entry(block_name)
        find("#{PALETTE_ENTRY_SELECTOR}[data-block-name='#{block_name}']")
      end

      # Drags a palette block onto a target element (a grid cell or an existing
      # block). Capybara's `drag_to` only simulates pointer events
      # (mousedown/move/up), which never initiates the native HTML5
      # drag-and-drop that PDND (`@atlaskit/pragmatic-drag-and-drop`, wiring the
      # editor's drag sources and grid drop target) listens for. So dispatch the
      # native drag sequence directly: `dragstart` on the tile, then
      # `dragenter`/`dragover` and `drop` over the target, sharing one
      # `DataTransfer` and carrying real cursor coordinates (the grid resolves
      # the drop cell from `clientX`/`clientY`). The `requestAnimationFrame` gaps
      # let PDND's frame-batched drop-target updates run between phases, mirroring
      # a real drag closely enough for its monitors to fire.
      # `at:` picks where inside the target the drop lands, which the grid turns
      # into a drop zone: `:center` drops in the middle (fills an empty cell, or
      # a no-op on an occupied one), `:trailing` drops near the far edge (the
      # "insert after" zone that cascades a new block into the following gap).
      # The editor's grid renders as a collapsed single-column stack here, so the
      # meaningful axis is vertical — `:trailing` drops near the bottom edge.
      DROP_Y_FRACTION = { center: 0.5, trailing: 0.85 }.freeze

      def drag_palette_block(block_name, onto:, at: :center)
        source = palette_entry(block_name)
        y_fraction = DROP_Y_FRACTION.fetch(at)

        # Phase 1 — start the drag on the tile. The shared DataTransfer lives on
        # `window` so it carries across the separate scripts (native dnd reuses
        # one DataTransfer for the whole gesture).
        page.execute_script(<<~JS, source)
          const source = arguments[0];
          window.__wfDragDataTransfer = new DataTransfer();
          const rect = source.getBoundingClientRect();
          source.dispatchEvent(
            new DragEvent("dragstart", {
              bubbles: true,
              cancelable: true,
              dataTransfer: window.__wfDragDataTransfer,
              clientX: rect.left + rect.width / 2,
              clientY: rect.top + rect.height / 2,
            })
          );
        JS

        # The `sleep` gaps yield to the browser between phases so PDND's
        # frame-batched drop-target bookkeeping runs — the grid publishes its
        # drop descriptor on dragover before the drop dispatches it.
        sleep 0.3

        # Phase 2 — move over the target so the grid resolves the drop cell from
        # the cursor coordinates and publishes its descriptor.
        page.execute_script(<<~JS, onto, y_fraction)
          const [target, yFraction] = arguments;
          const rect = target.getBoundingClientRect();
          const clientX = rect.left + rect.width / 2;
          const clientY = rect.top + rect.height * yFraction;
          for (const type of ["dragenter", "dragover"]) {
            target.dispatchEvent(
              new DragEvent(type, {
                bubbles: true,
                cancelable: true,
                dataTransfer: window.__wfDragDataTransfer,
                clientX,
                clientY,
              })
            );
          }
        JS

        sleep 0.3

        # Phase 3 — drop, then end the drag.
        page.execute_script(<<~JS, onto, source, y_fraction)
          const [target, source, yFraction] = arguments;
          const rect = target.getBoundingClientRect();
          const clientX = rect.left + rect.width / 2;
          const clientY = rect.top + rect.height * yFraction;
          target.dispatchEvent(
            new DragEvent("drop", {
              bubbles: true,
              cancelable: true,
              dataTransfer: window.__wfDragDataTransfer,
              clientX,
              clientY,
            })
          );
          source.dispatchEvent(
            new DragEvent("dragend", {
              bubbles: true,
              cancelable: true,
              dataTransfer: window.__wfDragDataTransfer,
              clientX,
              clientY,
            })
          );
          delete window.__wfDragDataTransfer;
        JS
      end

      def has_block_in_cell?(block_class, column:, row:)
        # Each grid child sits in a `.d-block-layout__cell` wrapper whose
        # placement is carried by the `--d-block-cell-column` /
        # `--d-block-cell-row` custom properties (core's `layout` block emits
        # them inline; see `blocks/builtin/layout.gjs`). Asserting against them
        # verifies the block landed in the EXPECTED cell, not merely somewhere
        # in the grid — so a drop into the wrong cell still fails.
        page.has_css?(
          "#{GRID_SELECTOR} " \
            ".d-block-layout__cell[style*='--d-block-cell-column: #{column}']" \
            "[style*='--d-block-cell-row: #{row}'] .#{block_class}",
          wait: 5,
        )
      end

      # Whether a block landed in a grid cell at all (any coordinate). Used when
      # the assertion is "the drop inserted a real block" rather than the exact
      # target cell — the precise placement math is covered by the JS gesture
      # test, and the resolved cell depends on whether the grid is rendering
      # expanded or as a collapsed single-column stack.
      def has_block_in_grid?(block_class)
        page.has_css?("#{GRID_SELECTOR} .d-block-layout__cell .#{block_class}", wait: 5)
      end
    end
  end
end
