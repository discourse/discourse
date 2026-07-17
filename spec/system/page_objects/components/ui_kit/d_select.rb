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
      end
    end
  end
end
