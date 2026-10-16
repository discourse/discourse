# frozen_string_literal: true

module PageObjects
  module Components
    class Tooltips < PageObjects::Components::Base
      SELECTOR = ".fk-d-tooltip__content"

      attr_reader :identifier

      def initialize(identifier)
        @identifier = identifier
      end

      def element(visible: true)
        browser_root.locator("#{SELECTOR}[data-identifier='#{identifier}']").filter(
          visible: visible,
        )
      end

      def find(selector, visible: true)
        element(visible: visible).locator(selector).filter(visible: visible)
      end

      def present?(text: nil, visible: true, wait: Capybara.default_max_wait_time)
        target = element(visible: visible)
        if text
          contain_text([text], useInnerText: true, timeout: wait * 1000).matches?(target)
        else
          have_count(0, timeout: wait * 1000).does_not_match?(target)
        end
      end

      def not_present?(text: nil, visible: true, wait: Capybara.default_max_wait_time)
        target = element(visible: visible)
        if text
          contain_text([text], useInnerText: true, timeout: wait * 1000).does_not_match?(target)
        else
          have_count(0, timeout: wait * 1000).matches?(target)
        end
      end
    end
  end
end
