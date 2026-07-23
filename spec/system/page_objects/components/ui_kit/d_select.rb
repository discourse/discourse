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

        # Whether the "keep filtering" hint is showing, i.e. a paginated source stopped at its
        # cap with more results behind it. A client source renders in full and never shows it.
        def narrow_hint?
          page.has_css?(".d-combobox__narrow", wait: 0)
        end

        # The listbox is windowed by `DVirtualList`: only a slice of rows is mounted, so
        # counting `[role='option']` elements measures the window, not the list. The extent
        # reached is instead the highest absolute `data-index` currently mounted — scrolling
        # the window toward the end advances it.
        def max_loaded_index
          page.evaluate_script(<<~JS)
            (function () {
              const indices = [...document.querySelectorAll("[role='listbox'] [role='option']")]
                .map((el) => Number(el.dataset.index))
                .filter((index) => Number.isInteger(index));
              return indices.length ? Math.max(...indices) : -1;
            })()
          JS
        end

        # Scrolls the listbox itself (never the page): scrolling the virtualized window toward
        # the end mounts the rows there. For a paginated source, reaching the end band also
        # trips the next fetch.
        def scroll_listbox_to_bottom
          page.execute_script(<<~JS)
            (function () {
              const list = document.querySelector(".d-virtual-list");
              list.scrollTop = list.scrollHeight;
            })()
          JS
        end

        # Scrolls toward the end until the mounted extent reaches `target` (an absolute index)
        # or stops growing. Each scroll to the bottom advances the window onto deeper rows (for
        # a paginated source it also trips the next fetch); the window then jumps to the new
        # bottom, so the wait is for the reachable frontier to advance past where it was — not
        # for a specific index (that low index is above the new window). A step that fails to
        # advance the frontier ends the loop (the list end, or a source cap, was reached).
        def reveal_to_index(target, max_scrolls: 25)
          max_scrolls.times do
            before = max_loaded_index
            break if before >= target
            scroll_listbox_to_bottom
            advanced = false
            20.times do
              if max_loaded_index > before
                advanced = true
                break
              end
              sleep 0.1
            end
            break unless advanced
          end
          max_loaded_index
        end

        # The absolute `data-index` of the option the combobox controller currently points at
        # via `aria-activedescendant`, or nil when the descendant is absent or not a mounted
        # option — the browser-truthful way to assert where a windowed keyboard jump landed.
        def active_option_index
          page.evaluate_script(<<~JS)
            (function () {
              const root = "#{@root}";
              const controller =
                document.querySelector(root + " [role='combobox']") ||
                document.querySelector(root + "[role='combobox']");
              const id = controller && controller.getAttribute("aria-activedescendant");
              const active = id && document.getElementById(id);
              if (!active || active.getAttribute("role") !== "option") {
                return null;
              }
              const index = Number(active.dataset.index);
              return Number.isInteger(index) ? index : null;
            })()
          JS
        end

        # Whether DOM focus rests on a mounted listbox option (focus-mode surfaces move real
        # focus into the list). Distinguishes a landed jump from focus dropped to `<body>`.
        def focused_option_index
          page.evaluate_script(<<~JS)
            (function () {
              const el = document.activeElement;
              if (!el || el.getAttribute("role") !== "option") {
                return null;
              }
              const index = Number(el.dataset.index);
              return Number.isInteger(index) ? index : null;
            })()
          JS
        end

        # Sends keys to the combobox controller (the trigger input, or the trigger div for a
        # select-only combobox).
        def press_in_controller(*keys)
          find("#{@root} [role='combobox']").send_keys(*keys)
        end

        # A windowed keyboard jump reconciles asynchronously (scroll, then refocus on the next
        # runloop), so the active option moves a beat after the keystroke. Polls until the
        # active index changes away from `previous` and returns it, failing if it never moves.
        def active_index_after_change(previous, timeout: 5)
          deadline = Time.now + timeout
          loop do
            current = active_option_index
            return current if current && current != previous
            raise "the active option never moved from #{previous.inspect}" if Time.now > deadline
            sleep 0.05
          end
        end
      end
    end
  end
end
