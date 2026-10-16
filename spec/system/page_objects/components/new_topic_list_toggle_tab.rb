# frozen_string_literal: true

module PageObjects
  module Components
    class NewTopicListToggleTab < PageObjects::Components::Base
      def initialize(name, selector)
        super()
        @name = name
        @selector = selector
      end

      def active?
        have_count(0).does_not_match?(
          browser_root.locator("#{@selector}.active").filter(visible: true),
        )
      end

      def inactive?
        have_count(0).matches?(browser_root.locator("#{@selector}.active").filter(visible: true)) &&
          have_count(0).does_not_match?(browser_root.locator(@selector).filter(visible: true))
      end

      def visible?
        have_count(0).does_not_match?(browser_root.locator(@selector).filter(visible: true))
      end

      def has_count?(count)
        expected_label =
          (
            if count > 0
              I18n.t("js.filters.new.#{@name}_with_count", count: count)
            else
              I18n.t("js.filters.new.#{@name}")
            end
          )

        contain_text([browser_text_pattern(expected_label)], useInnerText: true).matches?(
          browser_root.locator(@selector).filter(visible: true),
        )
      end

      def click
        browser_root.locator(@selector).filter(visible: true).click
      end
    end
  end
end
