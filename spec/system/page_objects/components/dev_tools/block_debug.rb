# frozen_string_literal: true

module PageObjects
  module Components
    module DevTools
      class BlockDebug < PageObjects::Components::Base
        # Outlet boundary methods
        def has_outlet_boundary?
          have_count(0).does_not_match?(
            browser_root.locator(".block-outlet-debug").filter(visible: true),
          )
        end

        def has_no_outlet_boundary?
          have_count(0).matches?(browser_root.locator(".block-outlet-debug").filter(visible: true))
        end

        def hover_outlet_badge(name = nil)
          selector =
            name ? ".block-outlet-debug[data-outlet-name='#{name}']" : ".block-outlet-debug"
          # Use JavaScript click to bypass any overlapping tooltip elements
          browser_page.evaluate(
            "function(arguments) { #{"document.querySelector(\"#{selector} .block-outlet-debug__badge\").click()"} }",
            arg: [],
          )
          self
        end

        def has_outlet_tooltip?
          have_count(0).does_not_match?(
            browser_root.locator(".outlet-info__wrapper").filter(visible: true),
          )
        end

        def has_outlet_github_link?
          have_count(0).does_not_match?(
            browser_root.locator(".outlet-info__heading .github-link").filter(visible: true),
          )
        end

        def has_outlet_block_count?(count)
          text = count == 1 ? "1 block" : "#{count} blocks"
          contain_text([browser_text_pattern(text)], useInnerText: true).matches?(
            browser_root.locator(".outlet-info__stat").filter(visible: true),
          )
        end

        # Block visual overlay methods
        def has_block_info?(block_name = nil)
          selector =
            block_name ? ".block-debug-info[data-block-name='#{block_name}']" : ".block-debug-info"
          have_count(0).does_not_match?(browser_root.locator(selector).filter(visible: true))
        end

        def has_no_block_info?(block_name = nil)
          selector =
            block_name ? ".block-debug-info[data-block-name='#{block_name}']" : ".block-debug-info"
          have_count(0).matches?(browser_root.locator(selector).filter(visible: true))
        end

        def hover_block_badge(block_name = nil)
          selector =
            block_name ? ".block-debug-info[data-block-name='#{block_name}']" : ".block-debug-info"
          # Use JavaScript click to bypass any overlapping tooltip elements
          browser_page.evaluate(
            "function(arguments) { #{"document.querySelector(\"#{selector} .block-debug-badge\").click()"} }",
            arg: [],
          )
          self
        end

        def has_block_tooltip?
          have_count(0).does_not_match?(
            browser_root.locator(".block-debug-tooltip").filter(visible: true),
          )
        end

        def has_block_title?(name)
          contain_text([browser_text_pattern(name)], useInnerText: true).matches?(
            browser_root.locator(".block-debug-tooltip__title").filter(visible: true),
          )
        end

        def has_block_location?(location)
          contain_text([browser_text_pattern(location)], useInnerText: true).matches?(
            browser_root.locator(".block-debug-tooltip__location").filter(visible: true),
          )
        end

        def has_block_arg?(key:)
          contain_text([browser_text_pattern("@#{key}")], useInnerText: true).matches?(
            browser_root.locator(".outlet-args-table__key").filter(visible: true),
          )
        end

        # Ghost block methods
        def has_ghost_block?(block_name = nil)
          selector =
            (
              if block_name
                ".block-debug-ghost[data-block-name='#{block_name}']"
              else
                ".block-debug-ghost"
              end
            )
          have_count(0).does_not_match?(browser_root.locator(selector).filter(visible: true))
        end

        def has_no_ghost_block?(block_name = nil)
          selector =
            (
              if block_name
                ".block-debug-ghost[data-block-name='#{block_name}']"
              else
                ".block-debug-ghost"
              end
            )
          have_count(0).matches?(browser_root.locator(selector).filter(visible: true))
        end

        def hover_ghost_badge(block_name = nil)
          selector =
            (
              if block_name
                ".block-debug-ghost[data-block-name='#{block_name}']"
              else
                ".block-debug-ghost"
              end
            )
          # Use JavaScript click to bypass any overlapping tooltip elements
          browser_page.evaluate(
            "function(arguments) { #{"document.querySelector(\"#{selector} .block-debug-ghost__badge\").click()"} }",
            arg: [],
          )
          self
        end

        def has_ghost_tooltip?
          have_count(0).does_not_match?(
            browser_root.locator(".block-debug-tooltip.--ghost").filter(visible: true),
          )
        end

        def has_conditions?
          have_count(0).does_not_match?(
            browser_root.locator(".block-debug-conditions").filter(visible: true),
          )
        end

        def has_failed_conditions?
          have_count(0).does_not_match?(
            browser_root.locator(".block-debug-conditions.--failed").filter(visible: true),
          )
        end

        def has_passed_conditions?
          have_count(0).does_not_match?(
            browser_root.locator(".block-debug-conditions.--passed").filter(visible: true),
          )
        end

        def has_condition_type?(type)
          contain_text([browser_text_pattern(type)], useInnerText: true).matches?(
            browser_root.locator(".block-debug-condition__type").filter(visible: true),
          )
        end

        def condition_types
          browser_root
            .locator(".block-debug-condition__type")
            .filter(visible: true)
            .tap { |elements| elements.first.wait_for(state: "visible") }
            .all
            .map { |element| element.inner_text.strip }
        end
      end
    end
  end
end
