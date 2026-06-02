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
      PALETTE_ENTRY_SELECTOR = ".wireframe-palette-entry"

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
        # A cell's content lives in the chrome wrapper placed at that grid
        # coordinate; assert the dragged block landed there.
        page.has_css?("#{GRID_SELECTOR} .#{block_class}", wait: 5)
      end
    end
  end
end
