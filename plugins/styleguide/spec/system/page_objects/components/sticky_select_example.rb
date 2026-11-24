# frozen_string_literal: true

module PageObjects
  module Components
    # Drives the sticky action example, including its viewport geometry.
    class StickySelectExample < UiKit::DSelect
      def initialize
        super(
          "[data-identifier='sg-content-sticky'][data-trigger]",
          panel: "[data-identifier='sg-content-sticky'][data-content]",
        )
      end

      def first_topic_label
        find("#{option_selector}[data-index='1']").text
      end

      def has_visible_suggestion?
        has_css?(
          "#{option_selector}.--sticky",
          text: I18n.t("js.styleguide.sections.select.content.sticky_action"),
        ) { |option| option.evaluate_script(<<~JS) }
            ((row) => {
              const viewport = row.closest(".d-virtual-list");
              const box = viewport.getBoundingClientRect();
              const rect = row.getBoundingClientRect();
              return viewport.scrollTop > 0 &&
                getComputedStyle(row).position === "sticky" &&
                rect.top >= box.top - 1 && rect.bottom <= box.bottom + 1;
            })(this)
          JS
      end

      def has_opaque_suggestion?
        has_css?("#{option_selector}.--sticky") { |option| option.evaluate_script(<<~JS) }
            (() => {
              const style = getComputedStyle(this);
              return style.backgroundColor.startsWith("rgb(") &&
                parseFloat(style.borderBottomWidth) > 0;
            })()
          JS
      end

      def choose_suggestion
        find("#{option_selector}.--sticky").click
      end

      def has_selected_topic?(label)
        has_css?("#{@root} .d-select__value", text: label)
      end
    end
  end
end
