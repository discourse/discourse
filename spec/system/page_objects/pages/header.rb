# frozen_string_literal: true

module PageObjects
  module Pages
    class Header < PageObjects::Pages::Base
      TOPIC_INFO_LINKS = { title: ".topic-link", category: "a.badge-category__wrapper" }.freeze

      def get_computed_style_value(selector, property)
        page.evaluate_script(
          "window.getComputedStyle(document.querySelector('#{selector}')).getPropertyValue('#{property}')",
        ).strip
      end

      def resize_element(selector, size)
        page.evaluate_script("document.querySelector('#{selector}').style.height = '#{size}px'")
      end

      def active_element_id
        current_active_element[:id]
      end

      def click_outside
        find(".d-modal").click(x: 0, y: 0)
      end

      def focus_topic_info_link(kind)
        find(topic_info_link_selector(kind)).execute_script("this.focus()")
      end

      def has_inset_topic_info_focus_outline?(kind)
        has_css?("#{topic_info_link_selector(kind)}:focus-visible") do |link|
          link.evaluate_script(<<~JS)
            (() => {
              const { outlineWidth, outlineOffset } = getComputedStyle(this);
              return parseFloat(outlineWidth) > 0 &&
                parseFloat(outlineOffset) <= -parseFloat(outlineWidth);
            })()
          JS
        end
      end

      private

      def topic_info_link_selector(kind)
        ".d-header .extra-info-wrapper #{TOPIC_INFO_LINKS.fetch(kind)}"
      end
    end
  end
end
