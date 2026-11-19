# frozen_string_literal: true

module PageObjects
  module Components
    class WireframeTabsEditor < PageObjects::Components::Base
      def enter
        find(".wireframe-pill").click
        find(".d-block-tabs__tab", text: "Community collection 1", exact_text: true).click
      end

      def scroll_forward
        find(".d-block-tabs__strip .d-overflow-controls__btn.--right").click
      end

      def rename_first_panel
        find(".d-block-tabs__tab", text: "Community collection 1", exact_text: true).click
        input = find(".d-block-tabs__tab [contenteditable='true']")
        input.set("Updated collection")
        input.send_keys(:left, :enter)
      end

      def has_renamed_panel?
        has_css?(".d-block-tabs__tab[aria-selected='true']", exact_text: "Updated collection")
      end

      def has_selected_panel?
        has_css?(".wireframe-block-chrome.--selected[data-wf-block-name='layout']")
      end

      def has_scrolled_tabs?
        has_css?(".d-block-tabs__tablist") { |strip| strip.evaluate_script("this.scrollLeft > 0") }
      end

      def has_interactive_overflow?
        has_css?(".d-block-tabs__strip .d-overflow-controls__btn.--right") do |button|
          button.evaluate_script("getComputedStyle(this).pointerEvents === 'auto'")
        end
      end
    end
  end
end
