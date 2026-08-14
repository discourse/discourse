# frozen_string_literal: true

module PageObjects
  module Components
    class TopicTimeline < PageObjects::Components::Base
      SCROLLER_SELECTOR = ".timeline-scroller"
      SCROLLAREA_SELECTOR = ".timeline-scrollarea"

      def has_scroller?
        has_css?(SCROLLER_SELECTOR)
      end

      # The timeline's own readout of where the reader is. Distinct from the
      # stream having loaded a post: a cloaked post keeps its `#post_N` id, so
      # `has_post_number?` is satisfied by a placeholder the reader never reached.
      def has_position?(current, total)
        has_css?("#{SCROLLER_SELECTOR} .timeline-replies", exact_text: "#{current} / #{total}")
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

      def has_dragging_scrollarea?
        has_css?("#{SCROLLAREA_SELECTOR}.--dragging")
      end

      def has_no_dragging_scrollarea?
        has_no_css?("#{SCROLLAREA_SELECTOR}.--dragging")
      end

      private

      def scrollarea_bottom
        page.evaluate_script(<<~JS)
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
