# frozen_string_literal: true

module PageObjects
  module Components
    class WireframePanelSwitcher < PageObjects::Components::Base
      def open_layers
        find(".wireframe-panel-switcher__entry[aria-label='Layers']").click
      end

      def toggle_collapsed
        find(".wireframe-panel-switcher__collapse").click
      end

      def resize_to_minimum
        find(".wireframe-rail-resizer--left").send_keys(:home)
      end

      def resize_to_maximum
        find(".wireframe-rail-resizer--left").send_keys(:end)
      end

      def has_layers_panel?
        has_css?(
          ".wireframe-panel-switcher [role='tabpanel'] .panel-header",
          exact_text: "Layers",
        ) &&
          has_css?(
            ".wireframe-panel-switcher [role='tab'][aria-label='Layers'][aria-selected='true']",
          )
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

      def has_collapsed_panel?
        has_no_css?(".wireframe-panel-switcher [role='tabpanel']") &&
          has_no_css?(".wireframe-rail-resizer--left") &&
          has_no_css?(".wireframe-panel-switcher [aria-selected='true']") &&
          has_css?(".wireframe-panel-switcher__collapse[aria-expanded='false']")
      end

      def has_aligned_panel?
        has_css?(".wireframe-panel-switcher") { |rail| rail.evaluate_script(<<~JS) }
            (() => {
              const strip = this.querySelector(".wireframe-panel-switcher__activity-bar").getBoundingClientRect();
              const panel = this.querySelector(".wireframe-panel.--left").getBoundingClientRect();
              const canvas = document.querySelector(".wireframe-canvas").getBoundingClientRect();
              const handle = document.querySelector(".wireframe-rail-resizer--left");
              const seam = handle.getBoundingClientRect();
              return Math.abs(strip.right - panel.left) < 1 &&
                Math.abs(panel.right - canvas.left) < 1 &&
                Math.abs(panel.width - Number(handle.getAttribute("aria-valuenow"))) < 1 &&
                Math.abs(panel.top - canvas.top) < 1 &&
                Math.abs(panel.bottom - canvas.bottom) < 1 &&
                Math.abs((seam.left + seam.right) / 2 - panel.right) < 1;
            })()
          JS
      end
    end
  end
end
