# frozen_string_literal: true

module PageObjects
  module Components
    module DevTools
      class BlockDebug < PageObjects::Components::Base
        # Outlet boundary methods
        def has_outlet_boundary?
          page.has_css?(".block-outlet-debug")
        end

        def has_no_outlet_boundary?
          page.has_no_css?(".block-outlet-debug")
        end

        def hover_outlet_badge(name = nil)
          selector =
            name ? ".block-outlet-debug[data-outlet-name='#{name}']" : ".block-outlet-debug"
          first("#{selector} .block-outlet-debug__badge").hover
          self
        end

        def has_outlet_tooltip?
          page.has_css?(".block-outlet-info__wrapper")
        end

        def has_outlet_github_link?
          page.has_css?(".block-outlet-info__heading .github-link")
        end

        # Block visual overlay methods
        def has_block_info?(block_name = nil)
          selector =
            block_name ? ".block-debug-info[data-block-name='#{block_name}']" : ".block-debug-info"
          page.has_css?(selector)
        end

        def hover_block_badge(block_name = nil)
          selector =
            block_name ? ".block-debug-info[data-block-name='#{block_name}']" : ".block-debug-info"
          find("#{selector} .block-debug-badge").hover
          self
        end

        def has_block_tooltip?
          page.has_css?(".block-debug-tooltip")
        end

        def has_block_title?(name)
          page.has_css?(".block-debug-tooltip__title", text: name)
        end

        def has_block_outlet?(outlet_name)
          page.has_css?(".block-debug-tooltip__outlet", text: outlet_name)
        end

        def has_block_arg?(key:)
          page.has_css?(".block-debug-args__key", text: key)
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
          page.has_css?(selector)
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
          find("#{selector} .block-debug-ghost__badge").hover
          self
        end

        def has_ghost_tooltip?
          page.has_css?(".block-debug-tooltip.--ghost")
        end

        def has_conditions?
          page.has_css?(".block-debug-conditions")
        end
      end
    end
  end
end
