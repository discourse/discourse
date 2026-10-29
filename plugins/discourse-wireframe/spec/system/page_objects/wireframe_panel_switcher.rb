# frozen_string_literal: true

module PageObjects
  module Components
    class WireframePanelSwitcher < PageObjects::Components::Base
      SECTIONS = ".wireframe-panel-switcher__sections"

      def open_layers
        select_section("outline")
      end

      def select_section(panel)
        find("#{SECTIONS} .d-segmented-control__label:has(input[value='#{panel}'])").click
      end

      def resize_to_minimum
        find(".wireframe-rail-resizer--left").send_keys(:home)
      end

      def resize_to_maximum
        find(".wireframe-rail-resizer--left").send_keys(:end)
      end

      def has_layers_panel?
        has_css?("#{SECTIONS} input[value='outline']:checked") &&
          has_css?(".wireframe-panel-switcher .panel-body .wireframe-outline")
      end

      def has_minimum_width?
        has_css?(".wireframe-rail-resizer--left") do |handle|
          handle["aria-valuenow"] == handle["aria-valuemin"]
        end
      end

      def has_maximum_width?
        has_css?(".wireframe-rail-resizer--left") do |handle|
          handle["aria-valuenow"] == handle["aria-valuemax"]
        end
      end

      def has_aligned_panel?
        has_css?(".wireframe-panel-switcher") { |panel| panel.evaluate_script(<<~JS) }
            (() => {
              const rect = this.getBoundingClientRect();
              const canvas = document.querySelector(".wireframe-canvas").getBoundingClientRect();
              const handle = document.querySelector(".wireframe-rail-resizer--left");
              const seam = handle.getBoundingClientRect();
              return Math.abs(rect.right - canvas.left) < 1 &&
                Math.abs(rect.width - Number(handle.getAttribute("aria-valuenow"))) < 1 &&
                Math.abs(rect.top - canvas.top) < 1 &&
                Math.abs(rect.bottom - canvas.bottom) < 1 &&
                Math.abs((seam.left + seam.right) / 2 - rect.right) < 1;
            })()
          JS
      end
    end
  end
end
