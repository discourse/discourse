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
    end
  end
end
