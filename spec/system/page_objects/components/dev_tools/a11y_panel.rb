# frozen_string_literal: true

module PageObjects
  module Components
    module DevTools
      class A11yPanel < PageObjects::Components::Base
        PANEL = ".d-panel-dock .dev-tools-a11y"

        def has_panel?
          page.has_css?(PANEL)
        end

        def has_no_panel?
          page.has_no_css?(PANEL)
        end

        def test_channel
          find("#{PANEL} .dev-tools-a11y__test-channel").click
          self
        end

        def pause
          find("#{PANEL} .dev-tools-a11y__pause").click
          self
        end

        def clear
          find("#{PANEL} .dev-tools-a11y__clear").click
          self
        end

        def has_intent_entry?
          page.has_css?("#{PANEL} .dev-tools-a11y__entry.--intent")
        end

        def has_spoken_entry?
          page.has_css?("#{PANEL} .dev-tools-a11y__entry.--spoken")
        end

        def has_empty_state?
          page.has_css?("#{PANEL} .dev-tools-a11y__empty")
        end

        def entry_count
          page.all("#{PANEL} .dev-tools-a11y__entry").size
        end

        def close_dock
          find(".d-panel-dock .d-panel-dock__close").click
          self
        end
      end
    end
  end
end
