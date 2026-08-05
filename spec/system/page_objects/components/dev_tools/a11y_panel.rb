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

        # The trigger opens a menu; the announcement comes from choosing a
        # channel inside it. Clicking only the trigger announces nothing, so a
        # spec that stops there waits for a delivery that was never requested.
        def test_channel(politeness = :polite)
          find("#{PANEL} .dev-tools-a11y__test-channel").click
          find(".dev-tools-a11y__test-#{politeness}").click
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

        # A DOM write into a live region is a delivery. It is not evidence any
        # assistive technology said anything, and the panel does not claim it is.
        def has_delivered_entry?
          page.has_css?("#{PANEL} .dev-tools-a11y__entry.--delivered")
        end

        def has_problem?
          page.has_css?("#{PANEL} .dev-tools-a11y__problem")
        end

        def has_no_problems?
          page.has_no_css?("#{PANEL} .dev-tools-a11y__problem")
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
