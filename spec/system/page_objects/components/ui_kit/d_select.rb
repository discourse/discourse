# frozen_string_literal: true

module PageObjects
  module Components
    module UiKit
      # Drives the ui-kit `DSelect` combobox (rendered as a typeahead). Scoped to one
      # instance by its trigger element, so the same page can host several.
      class DSelect < PageObjects::Components::Base
        # @param root [String] a CSS selector for the instance's `.d-combobox__trigger`.
        def initialize(root)
          @root = root
        end

        def trigger
          find(@root)
        end

        def input
          trigger.find(".d-combobox__input")
        end

        def open
          input.click
          self
        end

        def expanded?
          input[:"aria-expanded"] == "true"
        end

        def options
          all("[role='listbox'] [role='option']", minimum: 0)
        end

        # Single-select: open, filter, and click the matching option (closes the overlay).
        def select(name)
          input.click
          input.send_keys(name)
          find("[role='listbox'] [role='option']", text: name).click
          self
        end

        def chips
          trigger.all(".d-combobox__chip", minimum: 0)
        end

        def chip_labels
          chips.map { |chip| chip.find(".d-combobox__chip-label").text }
        end

        def remove_buttons
          trigger.all(".d-combobox__chip-remove", minimum: 0)
        end

        # Opens the overlay, types a filter, and clicks the matching option. The multi
        # overlay stays open across an add, so several calls chain without reopening.
        def add(name)
          input.click
          input.send_keys(name)
          find("[role='listbox'][aria-multiselectable='true'] [role='option']", text: name).click
        end

        def focus_input
          input.click
        end

        # Sends keys to whatever element currently holds focus (a chip or the input).
        def press(*keys)
          page.send_keys(*keys)
        end

        def input_focused?
          page.evaluate_script(
            "document.activeElement?.classList.contains('d-combobox__input') === true",
          )
        end

        # The label of the chip whose remove button holds focus, or nil when a chip is
        # not focused — the browser-truthful way to assert where roving landed.
        def focused_chip_label
          page.evaluate_script(<<~JS)
            (function () {
              const el = document.activeElement;
              if (!el || !el.classList.contains("d-combobox__chip-remove")) {
                return null;
              }
              const chip = el.closest(".d-combobox__chip");
              const label = chip && chip.querySelector(".d-combobox__chip-label");
              return label ? label.textContent.trim() : null;
            })()
          JS
        end

        def remove_button_tabindexes
          remove_buttons.map { |button| button[:tabindex] }
        end

        def listbox
          find("[role='listbox']")
        end

        def option_count
          options.size
        end

        # Whether the reveal sentinel is mounted. It disappears once the source stops offering
        # more — which a source does by saying so, or by saying nothing — or the cap is reached.
        def sentinel?
          page.has_css?("[role='listbox'] .d-combobox__sentinel", wait: 0)
        end

        # Whether the "keep filtering" hint is showing, i.e. the list is pinned at the cap
        # with more results behind it.
        def narrow_hint?
          page.has_css?(".d-combobox__narrow", wait: 0)
        end

        # Scrolls the listbox itself, which is the reveal sentinel's intersection root — the
        # page never scrolls for this control.
        def scroll_listbox_to_bottom
          page.execute_script(<<~JS)
            (function () {
              const list = document.querySelector("[role='listbox']");
              list.scrollTop = list.scrollHeight;
            })()
          JS
        end

        # Scrolls until `target` options are rendered. The reveal observer is debounced, so
        # each step waits for the count to grow rather than sleeping a fixed amount. Waiting
        # toward a known target keeps every wait a positive one, which resolves as soon as the
        # chunk lands instead of burning the full Capybara timeout.
        def reveal_until(target, max_scrolls: 12)
          max_scrolls.times do
            break if option_count >= target
            before = option_count
            scroll_listbox_to_bottom
            break unless page.has_css?("[role='listbox'] [role='option']", minimum: before + 1)
          end
          option_count
        end
      end
    end
  end
end
