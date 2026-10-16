# frozen_string_literal: true

module PageObjects
  module Components
    class TopicTimeline < PageObjects::Components::Base
      SCROLLER_SELECTOR = ".timeline-scroller"
      SCROLLAREA_SELECTOR = ".timeline-scrollarea"

      def has_scroller?
        have_count(0).does_not_match?(browser_root.locator(SCROLLER_SELECTOR).filter(visible: true))
      end

      # The timeline's own readout of where the reader is. Distinct from the
      # stream having loaded a post: a cloaked post keeps its `#post_N` id, so
      # `has_post_number?` is satisfied by a placeholder the reader never reached.
      def has_position?(current, total)
        contain_text(
          [browser_exact_text_pattern("#{current} / #{total}")],
          useInnerText: true,
        ).matches?(
          browser_root.locator("#{SCROLLER_SELECTOR} .timeline-replies").filter(visible: true),
        )
      end

      def drag_to_bottom
        drag_with_pointer(from: SCROLLER_SELECTOR, to: { x: 20, y: scrollarea_bottom })
      end

      def drag_by(y:, &block)
        drag_with_pointer(from: SCROLLER_SELECTOR, by: { y: y }, &block)
      end

      def has_dragging_page?
        have_count(0).does_not_match?(browser_root.locator("body.dragging").filter(visible: true))
      end

      def has_no_dragging_page?
        have_count(0).matches?(browser_root.locator("body.dragging").filter(visible: true))
      end

      def has_dragging_scrollarea?
        have_count(0).does_not_match?(
          browser_root.locator("#{SCROLLAREA_SELECTOR}.--dragging").filter(visible: true),
        )
      end

      def has_no_dragging_scrollarea?
        have_count(0).matches?(
          browser_root.locator("#{SCROLLAREA_SELECTOR}.--dragging").filter(visible: true),
        )
      end

      private

      def scrollarea_bottom
        browser_page.evaluate("function(arguments) { return #{<<~JS} }", arg: [])
          (() => {
            const area = document.querySelector("#{SCROLLAREA_SELECTOR}");
            const box = area.getBoundingClientRect();
            // Just inside the track, so the press lands on the scrollarea rather
            // than whatever sits immediately below it.
            return box.bottom - 4;
          })()
        JS
      end
    end
  end
end
