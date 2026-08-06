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

        # `wait: 0` because an EMPTY set is the expected answer much of the time, and
        # a waiting finder would burn the full Capybara timeout to discover that —
        # which this suite fails specs for.
        def problem_texts
          page.all("#{PANEL} .dev-tools-a11y__problem", wait: 0).map(&:text).uniq
        end

        def has_no_problems?
          page.has_no_css?("#{PANEL} .dev-tools-a11y__problem")
        end

        def has_empty_state?
          page.has_css?("#{PANEL} .dev-tools-a11y__empty")
        end

        # Rows of either shape. A burst of the same event collapses onto the noise
        # floor, which is NOT an entry row, so counting entries alone would let a
        # tab walk that produced one collapsed run look like nothing was captured —
        # or worse, pass on the unrelated region-watching row while the walk itself
        # went unrecorded.
        def row_count
          page.all("#{PANEL} .dev-tools-a11y__entry, #{PANEL} .dev-tools-a11y__noise").size
        end

        def has_captured_key_activity?
          page.has_css?(
            "#{PANEL} .dev-tools-a11y__entry .dev-tools-a11y__key, " \
              "#{PANEL} .dev-tools-a11y__noise",
          )
        end

        # `start` and `end` are the narrow side docks; `bottom` is the wide one. The
        # picker is a plain button group, so there is nothing to open first.
        def dock_to(side)
          find(".d-panel-dock__dock-button.--#{side}").click
          self
        end

        # Visibility, not presence: both Inspector copies are always in the DOM and a
        # container query hides one of them. Capybara's `visible:` respects that, which
        # an unscoped presence check cannot.
        def has_visible_inspector?(position)
          page.has_css?("#{PANEL} .dev-tools-a11y__inspector.--#{position}", visible: true)
        end

        def has_hidden_inspector?(position)
          page.has_css?("#{PANEL} .dev-tools-a11y__inspector.--#{position}", visible: :hidden)
        end

        def open_sweep
          find("#{PANEL} .dev-tools-a11y__view.--sweep").click
          find("#{PANEL} .dev-tools-a11y__sweep-scan").click
          self
        end

        # Matched on the stable ascii rule id rather than its wording, so the gate
        # does not move when a translation is reworded.
        def has_sweep_rule?(id)
          page.has_css?("#{PANEL} .dev-tools-a11y__sweep-rule", text: id)
        end

        def has_no_sweep_rule?(id)
          page.has_no_css?("#{PANEL} .dev-tools-a11y__sweep-rule", text: id)
        end

        # Rows collapse to a rule; the elements behind one appear only once it is
        # expanded, so a capture of the expanded shape has to ask for it.
        def expand_sweep_rule(id)
          find("#{PANEL} .dev-tools-a11y__sweep-rule", text: id).click
          self
        end

        def has_sweep_element_list?
          page.has_css?("#{PANEL} .dev-tools-a11y__sweep-element")
        end

        def open_regions
          find("#{PANEL} .dev-tools-a11y__view.--regions").click
          self
        end

        def has_region?(description)
          page.has_css?("#{PANEL} .dev-tools-a11y__region-id", text: description)
        end

        def has_region_message?(text)
          page.has_css?("#{PANEL} .dev-tools-a11y__region-message", text: text)
        end

        # The row's tier is carried by its class rather than by its wording, so this
        # holds when the finding's translation changes.
        def has_broken_region?(description)
          page.has_css?("#{PANEL} .dev-tools-a11y__region.--broken", text: description)
        end

        # Muting is keyed by region, so the row has to be found by its description
        # rather than by position: the order regions are discovered in is not fixed.
        def mute_region(description)
          find("#{PANEL} .dev-tools-a11y__region", text: description).find(
            ".dev-tools-a11y__mute",
          ).click
          self
        end

        def has_muted_region?(description)
          page.has_css?("#{PANEL} .dev-tools-a11y__region.--muted", text: description)
        end

        def close_dock
          find(".d-panel-dock .d-panel-dock__close").click
          self
        end
      end
    end
  end
end
