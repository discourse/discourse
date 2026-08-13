# frozen_string_literal: true

module PageObjects
  module Components
    module UiKit
      # Drives the ui-kit `DSelect` combobox (rendered as a typeahead). Scoped to one
      # instance by its trigger element, so the same page can host several.
      class DSelect < PageObjects::Components::Base
        # @param root [String] a CSS selector for the instance's `.d-combobox__trigger`.
        # @param panel [String, nil] a CSS selector for the instance's overlay. Without it
        #   panel lookups fall back to the whole document, which is only correct when a single
        #   overlay can be open at a time.
        def initialize(root, panel: nil)
          @root = root
          @panel = panel
        end

        # Identifiers reach both CSS attribute selectors (single-quoted) and double-quoted JS
        # string literals, so anything outside this set could break either. Rejecting is better
        # than escaping: every real identifier is a slug, and a silently-mangled selector fails
        # as a confusing timeout rather than an error.
        SAFE_IDENTIFIER = /\A[-_a-zA-Z0-9]+\z/

        # Scopes an instance by the `@identifier` it passes to `DMenu`. float-kit stamps that
        # identifier on the trigger *and* on the portaled overlay — on desktop through
        # `DFloatBody`, on mobile through `DModal` — so this is the only construction that
        # reaches the right panel on both.
        #
        # Note this scopes *lookups*; it does not make every method mobile-capable. `open` still
        # clicks an input inside the trigger, which on mobile lives in the modal instead — use
        # `open_trigger` there.
        def self.by_identifier(identifier)
          unless SAFE_IDENTIFIER.match?(identifier)
            raise ArgumentError, "unsafe DSelect identifier: #{identifier.inspect}"
          end

          new(
            "[data-identifier='#{identifier}'][data-trigger]",
            panel: "[data-identifier='#{identifier}'][data-content]",
          )
        end

        def trigger
          find(@root)
        end

        # `wait: 0` for the same reason as `press_in_controller`: a predicate on an
        # already-resolved node, where waiting would only delay a legitimate `false`.
        def multiple?
          trigger.matches_css?(".--multiple", wait: 0)
        end

        # Opens through the trigger itself rather than the query input — the `button` and
        # `static` variants have no input to click.
        def open_trigger
          trigger.click
          self
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

        # Prefixes a selector with this instance's overlay, so a page hosting several selects
        # never reads another one's panel. Falls back to the bare selector when the instance
        # was built without a panel root.
        def in_panel(selector)
          @panel ? "#{@panel} #{selector}" : selector
        end

        # Keeps the `[role='listbox']` ancestor the pre-scoping selector had: a panel may host
        # consumer markup (a `:footer`, an `:empty` block) that could carry its own option role,
        # and dropping the ancestor would let it count as a row.
        def option_selector
          in_panel("[role='listbox'] [role='option']")
        end

        def options
          all(option_selector, minimum: 0)
        end

        # Single-select: open, filter, and click the matching option (closes the overlay).
        def select(name)
          input.click
          input.send_keys(name)
          find(option_selector, text: name).click
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
          find(
            in_panel("[role='listbox'][aria-multiselectable='true'] [role='option']"),
            text: name,
          ).click
        end

        def focus_input
          input.click
        end

        # Sends keys to whatever element currently holds focus (a chip or the input).
        def press(*keys)
          page.send_keys(*keys)
        end

        # The elements this instance owns live in two disjoint subtrees: the host trigger, and
        # the portaled overlay. A focus predicate has to accept either, because the typeahead
        # input sits in the trigger on desktop and inside the modal on mobile.
        def owned_scopes
          @panel ? [@root, @panel] : [@root]
        end

        # A selector matching `descendant:focus` in either subtree this instance owns, as a
        # single CSS list so one waiting matcher covers both.
        def owned_focus_selector(descendant)
          owned_scopes.map { |scope| "#{scope} #{descendant}:focus" }.join(", ")
        end

        # Whether focus rests on THIS instance's query input.
        #
        # A waiting matcher, not a `document.activeElement` sample. The component moves focus
        # from a runloop callback after the keystroke that triggers it, so reading once races
        # the very transition being asserted: it passes when the machine is idle and fails under
        # load, which is exactly the shape of an order-dependent flake.
        def input_focused?
          page.has_css?(owned_focus_selector(".d-combobox__input"))
        end

        # The waiting negative. `input_focused?` returning false costs a full timeout and cannot
        # tell "not yet" from "never", so asserting focus is elsewhere needs the absence matcher.
        def input_blurred?
          page.has_no_css?(owned_focus_selector(".d-combobox__input"))
        end

        # The label of the chip whose remove button holds focus, or nil when no chip takes focus
        # — the browser-truthful way to assert where roving landed. Waits for the focus move for
        # the same reason as `input_focused?` before reading the label back.
        def focused_chip_label
          return nil unless page.has_css?(owned_focus_selector(".d-combobox__chip-remove"))

          page.evaluate_script(<<~JS)
            (function () {
              const el = document.activeElement;
              if (!el || !el.classList.contains("d-combobox__chip-remove")) {
                return null;
              }
              if (!#{owned_scopes.to_json}.some((scope) => el.closest(scope))) {
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

        # The query input for a panel-searchable (`button`) variant, which renders inside the
        # portaled overlay rather than in the trigger. `input` reaches the typeahead's trigger
        # input instead, and finds nothing here: the panel builds its filter from `DFilterInput`
        # (an `input.filter-input`), not the typeahead's `.d-combobox__input`. The class DSelect
        # puts on it is what both variants have in common to key on.
        def panel_input
          find(in_panel(".d-combobox__filter"))
        end

        def panel_input_focused?
          page.has_css?(owned_focus_selector(".d-combobox__filter"))
        end

        # Whether DOM focus rests anywhere in this instance's overlay, the panel itself included.
        # Waiting matchers rather than an `activeElement` sample, for the reason `input_focused?`
        # documents: focus moves a beat after the keystroke that causes it.
        def panel_focused?
          @panel ? page.has_css?("#{@panel}:focus, #{@panel} :focus") : false
        end

        def panel_blurred?
          @panel ? page.has_no_css?("#{@panel}:focus, #{@panel} :focus") : true
        end

        # Whether focus rests on the windowed list's scroll viewport — the element a browser
        # with keyboard-focusable scrollers will adopt as a tab stop when the list carries no
        # focusable descendants of its own. Paired with the waiting negative, since asserting
        # focus is elsewhere through `has_css?` costs a full timeout on every run.
        def list_scroller_focused?
          page.has_css?(in_panel(".d-virtual-list:focus"))
        end

        def list_scroller_blurred?
          page.has_no_css?(in_panel(".d-virtual-list:focus"))
        end

        # The `tabindex` the windowed list's scroll viewport carries, or nil for none.
        def list_scroller_tabindex
          find(in_panel(".d-virtual-list"))[:tabindex]
        end

        def trigger_focused?
          page.has_css?("#{@root}:focus")
        end

        # Whether focus rests on a control the consumer yielded into the panel's `:footer`, or on
        # the error state's retry action. Both live in the portaled panel rather than the trigger,
        # so they are only reachable once the panel participates in the tab sequence.
        def footer_control_focused?
          page.has_css?(in_panel(".d-combobox__footer button:focus"))
        end

        def retry_focused?
          page.has_css?(in_panel(".d-combobox__retry:focus"))
        end

        # Whether DOM focus rests anywhere this instance owns — the trigger subtree or the panel.
        # The waiting negative is the useful direction: it is how a test asserts Tab left the
        # widget entirely without paying a full timeout for a `has_css?` that will never match.
        def widget_focused?
          page.has_css?(owned_scopes.map { |scope| "#{scope}:focus, #{scope} :focus" }.join(", "))
        end

        def widget_blurred?
          page.has_no_css?(
            owned_scopes.map { |scope| "#{scope}:focus, #{scope} :focus" }.join(", "),
          )
        end

        # Stamps `data-tab-oracle` on the host-document tab stops immediately before and after
        # this instance's trigger, so a test can name where Tab *should* land without hard-coding
        # a neighbouring example's markup.
        #
        # Must run while the overlay is CLOSED. The overlay is portaled to the end of the
        # document, so once open its own controls enumerate as host tab stops and the neighbour
        # this computes is no longer the one the user would reach.
        #
        # Returns the enumeration for the caller to sanity-check, since a page whose trigger has
        # no following tab stop would satisfy a "focus left the widget" assertion vacuously.
        def mark_tab_order_oracle
          page.evaluate_script(<<~JS)
            (function () {
              const SELECTOR = [
                "a[href]",
                "button:not([disabled])",
                "input:not([disabled])",
                "select:not([disabled])",
                "textarea:not([disabled])",
                "summary",
                "[tabindex]:not([tabindex='-1'])",
              ].join(", ");

              document
                .querySelectorAll("[data-tab-oracle]")
                .forEach((el) => el.removeAttribute("data-tab-oracle"));

              const trigger = document.querySelector("#{@root}");
              if (!trigger) {
                return null;
              }

              const tabbables = [...document.querySelectorAll(SELECTOR)].filter((el) => {
                if (el.closest("[aria-hidden='true']")) {
                  return false;
                }
                return !!(el.offsetWidth || el.offsetHeight || el.getClientRects().length);
              });

              const index = tabbables.indexOf(trigger);
              if (index === -1) {
                return null;
              }

              const before = tabbables[index - 1];
              const after = tabbables[index + 1];
              if (before) {
                before.setAttribute("data-tab-oracle", "before");
              }
              if (after) {
                after.setAttribute("data-tab-oracle", "after");
              }

              return { hasBefore: !!before, hasAfter: !!after };
            })()
          JS
        end

        def listbox
          find(in_panel("[role='listbox']"))
        end

        # Presence predicates for THIS instance's overlay. Asserting on a bare `[role='listbox']`
        # is both over-broad (any open panel satisfies it) and flaky in the negative direction,
        # since a document-wide `have_no_css` has to wait out every candidate.
        def has_listbox?
          page.has_css?(in_panel("[role='listbox']"))
        end

        def has_no_listbox?
          page.has_no_css?(in_panel("[role='listbox']"))
        end

        def option_count
          options.size
        end

        # Whether the "keep filtering" hint is showing, i.e. a paginated source stopped at its
        # cap with more results behind it. A client source renders in full and never shows it.
        def narrow_hint?
          page.has_css?(in_panel(".d-combobox__narrow"), wait: 0)
        end

        # The listbox is windowed by `DVirtualList`: only a slice of rows is mounted, so
        # counting `[role='option']` elements measures the window, not the list. The extent
        # reached is instead the highest absolute `data-index` currently mounted — scrolling
        # the window toward the end advances it.
        def max_loaded_index
          page.evaluate_script(<<~JS)
            (function () {
              const indices = [...document.querySelectorAll("#{option_selector}")]
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
              const list = document.querySelector("#{in_panel(".d-virtual-list")}");
              list.scrollTop = list.scrollHeight;
            })()
          JS
        end

        # The scroll offset of this instance's windowed viewport — the assertion that scrolling
        # stayed inside the listbox rather than moving the page.
        def list_scroll_top
          page.evaluate_script(<<~JS)
            (function () {
              const list = document.querySelector("#{in_panel(".d-virtual-list")}");
              return list ? list.scrollTop : null;
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
              if (!#{owned_scopes.to_json}.some((scope) => el.closest(scope))) {
                return null;
              }
              const index = Number(el.dataset.index);
              return Number.isInteger(index) ? index : null;
            })()
          JS
        end

        # Sends keys to the combobox controller (the trigger input, or the trigger div for a
        # select-only combobox). The `static` variant puts `role="combobox"` on the trigger root
        # itself, so a descendant-only lookup would never find it.
        def press_in_controller(*keys)
          # `trigger` does the waiting, so by here the element exists and the role question is
          # about that resolved node — `wait: 0` is correct and not a race. Without it
          # `matches_css?` waits the full Capybara duration before answering false, which is a
          # 5s stall on every typeahead (the variant where the role is on a descendant).
          root = trigger
          controller =
            if root.matches_css?("[role='combobox']", wait: 0)
              root
            else
              root.find("[role='combobox']")
            end
          controller.send_keys(*keys)
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
