# frozen_string_literal: true

module PageObjects
  module Components
    class WireframeGridResize < PageObjects::Components::Base
      FILLED_CELL = ".wireframe-block-chrome[data-wf-block-name='heading']"
      HANDLE = ".wireframe-block-chrome__resize-handle"

      def select_filled_cell
        find(FILLED_CELL).click
      end

      def has_positioned_filled_handles?
        positions = {
          "nw" => [0, 0],
          "n" => [0.5, 0],
          "ne" => [1, 0],
          "e" => [1, 0.5],
          "se" => [1, 1],
          "s" => [0.5, 1],
          "sw" => [0, 1],
          "w" => [0, 0.5],
        }
        has_css?("#{FILLED_CELL} #{HANDLE}", count: 8) do |handle|
          geometry = handle.evaluate_script(<<~JS)
            (() => {
              const frame = this.closest('.wireframe-block-chrome').getBoundingClientRect();
              const handle = this.getBoundingClientRect();
              return {
                x: (handle.x + handle.width / 2 - frame.x) / frame.width,
                y: (handle.y + handle.height / 2 - frame.y) / frame.height,
                width: handle.width,
                height: handle.height
              };
            })()
          JS
          x, y = positions.fetch(handle["data-resize-handle"])
          geometry["width"] > 0 && geometry["height"] > 0 && (geometry["x"] - x).abs < 0.03 &&
            (geometry["y"] - y).abs < 0.03
        end
      end

      def resize_filled_cell(direction, column:, row:)
        drag_handle("#{FILLED_CELL} #{HANDLE}.--#{direction}", column:, row:)
      end

      def resize_empty_cell(column:, row:, direction:, to_column:, to_row:)
        cell = ".wireframe-grid-cell[data-col='#{column}'][data-row='#{row}']"
        find(cell).click
        drag_handle("#{cell} #{HANDLE}.--#{direction}", column: to_column, row: to_row)
      end

      def has_filled_span?(column:, row:)
        has_span?(FILLED_CELL, column:, row:)
      end

      def has_empty_span?(column:, row:)
        has_span?(".wireframe-block-chrome[data-wf-block-name='layout-merged-cell']", column:, row:)
      end

      private

      def drag_handle(selector, column:, row:)
        rect =
          find(".d-block-layout--grid").evaluate_script("this.getBoundingClientRect().toJSON()")
        drag_with_pointer(
          from: selector,
          to: {
            x: rect["x"] + rect["width"] * (column - 0.5) / 3,
            y: rect["y"] + rect["height"] * (row - 0.5) / 3,
          },
        )
      end

      def has_span?(selector, column:, row:)
        has_css?(selector) { |cell| cell.evaluate_script(<<~JS) == [column, row] }
            (() => {
              const style = getComputedStyle(this.closest('.d-block-layout__cell'));
              return [style.gridColumn, style.gridRow];
            })()
          JS
      end
    end
  end
end
