import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import {
  click,
  fillIn,
  find,
  render,
  settled,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import A11yLiveRegions from "discourse/components/a11y/live-regions";
import { disableClearA11yAnnouncementsInTests } from "discourse/services/a11y";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DSelect from "discourse/ui-kit/select/d-select";

// Oracle for "the flip" — routing @multiple through the typeahead machinery so a
// multi-select renders chips inline with a typeahead input. This file is the fixed spec
// for the paired-build handoff: it pins the observable post-flip contract, especially the
// SILENT failure modes (a tree that compiles/type-checks/lints green while the widget is
// functionally destroyed). It is authored test-first and proven RED against the pre-flip
// tree before the implementation is delegated. Kept in its own file, separate from the
// existing d-select-test.gjs, so the implementer's test updates never touch the oracle.

const ITEMS = [
  { id: 1, name: "Apple" },
  { id: 2, name: "Banana" },
  { id: 3, name: "Cherry pie" },
];

// A controlled host: it owns @value and updates it from @onChange, exactly as a consumer
// (or FormKit) does. The inline query input lives in the trigger, so the trigger-scoped
// `[role='combobox']` selector below is the flip's headline observable.
class MultiHost extends Component {
  @tracked value = this.args.value ?? [];

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @multiple={{true}}
      @items={{ITEMS}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @placeholder="Add some"
      @identifier="oracle-multi"
    >
      <:selection as |item|>{{item.name}}</:selection>
      <:item as |item|>{{item.name}}</:item>
    </DSelect>
  </template>
}

const TRIGGER_INPUT = ".d-combobox__trigger [role='combobox']";

module(
  "Integration | ui-kit | select | DSelect multi flip (oracle)",
  function (hooks) {
    setupRenderingTest(hooks);

    test("the multi trigger is an inline combobox present before opening", async function (assert) {
      await render(<template><MultiHost /></template>);

      // The flip's headline: multi is now a typeahead, so the trigger itself hosts the
      // query input. Pre-flip the trigger holds chips + an expand button and no inline
      // combobox — this assertion is the primary RED signal.
      assert
        .dom(TRIGGER_INPUT)
        .exists("the multi trigger hosts an inline combobox input")
        .hasAttribute("aria-autocomplete", "list");
      assert.dom("[role='listbox']").doesNotExist("closed on render");
    });

    test("typing in the inline input filters the list and drives the highlight (keyboard-alive)", async function (assert) {
      await render(<template><MultiHost /></template>);

      // If the flip silently kills the keyboard path (panel filter vanishes → filterInput
      // null → dRovingFocus controllerElement null), typing here would neither filter nor
      // highlight. Guards the "keyboard dead, no error" silent break.
      assert.dom(TRIGGER_INPUT).exists("inline input is present to type into");
      await fillIn(TRIGGER_INPUT, "ban");

      assert.dom("[role='listbox']").exists("typing opens the list");
      assert.dom("[role='option']").exists({ count: 1 }).hasText("Banana");

      const active = find("[role='option'].--active");
      assert.dom(active).hasText("Banana", "the match is highlighted");
      assert
        .dom(TRIGGER_INPUT)
        .hasAttribute(
          "aria-activedescendant",
          active.id,
          "aria-activedescendant points at the highlighted option"
        );
    });

    test("auto-highlights the first match; Enter adds it without an ArrowDown", async function (assert) {
      await render(<template><MultiHost /></template>);

      assert.dom(TRIGGER_INPUT).exists("inline input is present");
      await fillIn(TRIGGER_INPUT, "app");
      await triggerKeyEvent(TRIGGER_INPUT, "keydown", "Enter");

      // autoActivateFirst flips true for multi, so Enter selects the highlighted first
      // match with no explicit navigation — and multi keeps the menu open on select.
      assert
        .dom(".d-combobox__chip")
        .exists({ count: 1 }, "the highlighted match becomes a chip");
      // Assert on the label span, not the whole chip — the chip also contains the
      // remove button's sr-only "Remove" text.
      assert.dom(".d-combobox__chip-label").hasText("Apple");
      assert.dom("[role='listbox']").exists("multi stays open after a pick");
    });

    test("selecting adds a chip, keeps the menu open, clears the query, keeps input focus, flags the row", async function (assert) {
      await render(<template><MultiHost /></template>);

      assert.dom(TRIGGER_INPUT).exists("inline input is present");
      await fillIn(TRIGGER_INPUT, "ban");
      await click("[role='option']");

      assert.dom(".d-combobox__chip").exists({ count: 1 }, "a chip is added");
      assert.dom(".d-combobox__chip-label").hasText("Banana");
      assert.dom("[role='listbox']").exists("the menu stays open");
      assert
        .dom("[role='listbox']")
        .hasAttribute(
          "aria-multiselectable",
          "true",
          "the listbox declares multi-select semantics"
        );
      assert
        .dom(TRIGGER_INPUT)
        .hasValue("", "the query is reset after the add");
      assert.strictEqual(
        document.activeElement,
        find(TRIGGER_INPUT),
        "focus stays in the query input across the add"
      );
      assert
        .dom("[role='option'][aria-selected='true']")
        .hasText(
          "Banana",
          "the picked row stays in the list, flagged selected"
        );
    });

    test("the query resets only on ADD — removing a chip mid-query keeps the typed text", async function (assert) {
      await render(<template><MultiHost @value={{array 1 2}} /></template>);

      assert.dom(TRIGGER_INPUT).exists("inline input is present");
      await fillIn(TRIGGER_INPUT, "cher");
      // Remove a chip mid-query (its inner × button); the reset must NOT fire on removal.
      await click(".d-combobox__chip .d-combobox__chip-remove");

      assert
        .dom(TRIGGER_INPUT)
        .hasValue("cher", "removing a chip does not wipe the typed query");
      assert.dom(".d-combobox__chip").exists({ count: 1 }, "one chip removed");
    });

    test("Backspace on the empty input removes the last chip; not with text; not mid-composition", async function (assert) {
      await render(<template><MultiHost @value={{array 1 2}} /></template>);

      const input = find(TRIGGER_INPUT);
      assert.dom(input).exists("inline input is present");
      assert.dom(".d-combobox__chip").exists({ count: 2 });

      // Empty input + Backspace → remove the last chip.
      input.focus();
      await triggerKeyEvent(input, "keydown", "Backspace");
      assert
        .dom(".d-combobox__chip")
        .exists(
          { count: 1 },
          "Backspace on the empty input removes the last chip"
        );

      // With text in the input, Backspace edits text and must NOT remove a chip.
      await fillIn(input, "x");
      await triggerKeyEvent(input, "keydown", "Backspace");
      assert
        .dom(".d-combobox__chip")
        .exists(
          { count: 1 },
          "Backspace with text in the input does not remove a chip"
        );

      // Mid-IME-composition Backspace reaches the external listener (the internal handler
      // does not shield it), so the guard must be `!event.isComposing`.
      await fillIn(input, "");
      input.dispatchEvent(
        new KeyboardEvent("keydown", {
          key: "Backspace",
          isComposing: true,
          bubbles: true,
          cancelable: true,
        })
      );
      await settled();
      assert
        .dom(".d-combobox__chip")
        .exists({ count: 1 }, "a composing Backspace does not remove a chip");
    });

    test("removing a chip via its × keeps the menu open and does not crash", async function (assert) {
      await render(<template><MultiHost @value={{array 1 2}} /></template>);

      assert.dom(TRIGGER_INPUT).exists("inline input is present");
      // Open via the inline input path (typing), which is the flip's open affordance.
      await fillIn(TRIGGER_INPUT, "");
      await triggerKeyEvent(TRIGGER_INPUT, "keydown", "ArrowDown");
      assert.dom("[role='listbox']").exists("the menu is open");

      await click(".d-combobox__chip .d-combobox__chip-remove");
      assert
        .dom("[role='listbox']")
        .exists("removing a chip keeps the menu open");
      assert.dom(".d-combobox__chip").exists({ count: 1 }, "one chip removed");
    });

    test("adding announces 'Added <label>' politely with no trailing result count", async function (assert) {
      disableClearA11yAnnouncementsInTests();

      await render(
        <template>
          <MultiHost />
          <A11yLiveRegions />
        </template>
      );

      assert.dom(TRIGGER_INPUT).exists("inline input is present");
      await fillIn(TRIGGER_INPUT, "ban");
      await click("[role='option']");

      // The add is announced; the self-inflicted refilter's count must be suppressed so the
      // screen reader hears "Added Banana", not "Added Banana. 3 results".
      assert
        .dom("#a11y-announcements-polite")
        .hasText(
          "Added Banana",
          "the add is announced without a trailing result count"
        );
    });

    test("the count-suppress flag does not leak: add with an empty query, then filtering still announces the count", async function (assert) {
      disableClearA11yAnnouncementsInTests();

      await render(
        <template>
          <MultiHost />
          <A11yLiveRegions />
        </template>
      );

      assert.dom(TRIGGER_INPUT).exists("inline input is present");
      // Add with an EMPTY query — setFilter("") is a no-op, so announceCount never fires to
      // consume a one-shot flag. A leaked flag would swallow the NEXT genuine count.
      await triggerKeyEvent(TRIGGER_INPUT, "keydown", "ArrowDown");
      await click("[role='option']");

      // Now a real user query: its result count MUST be announced (the flag did not leak).
      await fillIn(TRIGGER_INPUT, "cherry");

      assert
        .dom("#a11y-announcements-polite")
        .includesText(
          "result",
          "a genuine post-add filter still announces its count"
        );
    });

    test("a suppressed count still records last-known, so a later genuine search is announced", async function (assert) {
      disableClearA11yAnnouncementsInTests();

      await render(
        <template>
          <MultiHost />
          <A11yLiveRegions />
        </template>
      );

      assert.dom(TRIGGER_INPUT).exists("inline input is present");
      // Filter to one match, announcing its count.
      await fillIn(TRIGGER_INPUT, "ban");

      // Pick it: the add resets the query and the restored full-list count is suppressed. The
      // suppressed count must still be recorded as last-known.
      await click("[role='option']");

      // Search the same term again: the count returns to 1. If the suppressed count was not
      // recorded, this would look like a repeat of the pre-suppression count and be swallowed.
      await fillIn(TRIGGER_INPUT, "ban");

      assert
        .dom("#a11y-announcements-polite")
        .includesText(
          "result",
          "the repeated genuine search re-announces its count (suppress did not go stale)"
        );
    });
  }
);
