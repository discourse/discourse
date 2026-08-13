# frozen_string_literal: true

module PageObjects
  module Components
    class TopicTimeline < PageObjects::Components::Base
      SCROLLER_SELECTOR = ".timeline-scroller"
      SCROLLAREA_SELECTOR = ".timeline-scrollarea"

      def has_scroller?
        has_css?(SCROLLER_SELECTOR)
      end

      def drag_to_bottom
        drag_with_pointer(from: SCROLLER_SELECTOR, to: { x: 20, y: scrollarea_bottom })
      end

      def drag_by(y:, &block)
        drag_with_pointer(from: SCROLLER_SELECTOR, by: { y: y }, &block)
      end

      def has_dragging_page?
        has_css?("body.dragging")
      end

      def has_no_dragging_page?
        has_no_css?("body.dragging")
      end

      private

      def scrollarea_bottom
        page.evaluate_script(<<~JS)
          (() => {
            const area = document.querySelector("#{SCROLLAREA_SELECTOR}");
            const box = area.getBoundingClientRect();
            return box.top + box.height - 4;
          })()
        JS
      end
    end
  end
end
