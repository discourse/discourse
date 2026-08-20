# frozen_string_literal: true

module PageObjects
  module Pages
    # Drives the wireframe editor for system tests: entering edit mode and
    # locating the live-rendered grid, its cells, and the palette so a real
    # native drag (`drag_palette_block`) can be performed and its result
    # asserted.
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

      def block_selector(name)
        ".#{name}"
      end

      def empty_cell_selector(column:, row:)
        "#{EMPTY_CELL_SELECTOR}[data-col='#{column}'][data-row='#{row}']"
      end

      # Drags a palette block onto a target (a grid cell or an existing block,
      # given as a CSS selector). Thin wireframe-specific sugar over the shared
      # `SystemHelpers#drag_and_drop` native-drag helper — Capybara's `drag_to`
      # can't drive the PDND-backed core drag modifiers (it fires `dragstart`
      # and then stalls), which is why we go through the shared helper.
      #
      # `at:` picks where inside the target the drop lands, which the grid turns
      # into a drop zone. The editor grid renders as a collapsed single-column
      # stack here, so the meaningful axis is vertical: `:center` drops in the
      # middle (fills an empty cell, or a no-op swap onto an occupied one) and
      # `:trailing` drops near the bottom edge (the "insert after" zone).
      def drag_palette_block(block_name, onto:, at: :center)
        source = "#{PALETTE_ENTRY_SELECTOR}[data-block-name='#{block_name}']"

        target_position = nil
        if at == :trailing
          # Drop near the bottom edge so the collapsed stack resolves an "insert
          # after" rather than a swap/no-op onto the occupied cell's centre.
          box = page.driver.with_playwright_page { |pw| pw.query_selector(onto).bounding_box }
          target_position = { x: box["width"] / 2.0, y: box["height"] * 0.85 }
        end

        drag_and_drop(source: source, target: onto, target_position: target_position)
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
