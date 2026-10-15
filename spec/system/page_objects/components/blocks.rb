# frozen_string_literal: true

module PageObjects
  module Components
    class Blocks < PageObjects::Components::Base
      def has_block?(name)
        PlaywrightMatchers.have_count(0, timeout: 5 * 1000).does_not_match?(
          browser_root.locator(".block-#{name}").filter(visible: true),
        )
      end

      def has_no_block?(name)
        PlaywrightMatchers.have_count(0, timeout: 5 * 1000).matches?(
          browser_root.locator(".block-#{name}").filter(visible: true),
        )
      end

      def block_text(name)
        browser_root.locator(".block-#{name}").filter(visible: true).inner_text.strip
      end

      def block_count(outlet_name)
        browser_root
          .locator("[class*='#{outlet_name}__block']")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all
          .count
      end

      def ordered_blocks_in_outlet(outlet_name)
        browser_root
          .locator(".#{outlet_name}__block [data-order]")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all
          .map { |el| el.get_attribute("data-order").to_i }
      end

      def has_blocks_in_order?(expected_order)
        actual = ordered_blocks_in_outlet("hero-blocks")
        actual == expected_order
      end
    end
  end
end
