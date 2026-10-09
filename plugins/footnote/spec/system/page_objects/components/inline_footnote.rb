# frozen_string_literal: true

module PageObjects
  module Components
    class InlineFootnote < PageObjects::Components::Base
      CONTENT_SELECTOR = ".fk-d-tooltip__inner-content"

      def open
        find("a.expand-footnote").click
      end

      def within_screen?
        settled { popup_within_screen? }
      end

      def scrollable?
        content.evaluate_script("this.scrollHeight > this.clientHeight")
      end

      def scroll_to_bottom
        content.scroll_to(:bottom)
      end

      def has_scrolled_to?(text)
        tooltip.find("#{CONTENT_SELECTOR} p", text: text).evaluate_script(<<~JS)
          (() => {
            const scrollport = this.closest("#{CONTENT_SELECTOR}").getBoundingClientRect();

            return this.getBoundingClientRect().bottom <= scrollport.bottom + 1;
          })()
        JS
      end

      def has_no_horizontal_page_scroll?
        settled do
          evaluate_script(
            "document.documentElement.scrollWidth <= document.documentElement.clientWidth",
          )
        end
      end

      private

      def tooltip
        @tooltip ||= PageObjects::Components::Tooltips.new("inline-footnote")
      end

      def content
        tooltip.find(CONTENT_SELECTOR)
      end

      # the float is animated and positioned asynchronously, so a geometry read taken right
      # after it opens can measure it mid-flight
      def settled(&block)
        try_until_success { expect(block.call).to eq(true) }
        true
      rescue RSpec::Expectations::ExpectationNotMetError
        false
      end

      def popup_within_screen?
        tooltip.element.evaluate_script(<<~JS)
          (() => {
            const { top, bottom, left, right } = this.getBoundingClientRect();

            return top >= 0 && left >= 0 &&
              bottom <= window.innerHeight && right <= window.innerWidth;
          })()
        JS
      end
    end
  end
end
