import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import {
  click,
  fillIn,
  find,
  findAll,
  render,
  settled,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import A11yLiveRegions from "discourse/components/a11y/live-regions";
import { disableClearA11yAnnouncementsInTests } from "discourse/services/a11y";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DSelect from "discourse/ui-kit/select/d-select";

// Routing @multiple through the typeahead machinery: a multi-select renders chips inline
// with a typeahead input. These tests target the SILENT failure modes — the ones where the
// tree compiles, type-checks and lints green while the widget is functionally destroyed —
// so they assert observable behaviour rather than structure wherever the two differ.

const ITEMS = [
  { id: 1, name: "Apple" },
  { id: 2, name: "Banana" },
  { id: 3, name: "Cherry pie" },
];

// A controlled host: it owns @value and updates it from @onChange, exactly as a consumer
// (or FormKit) does. The inline query input lives in the trigger, so the selector below is
// scoped to the trigger.
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
      @identifier="multi-flip"
    >
      <:selection as |item|>{{item.name}}</:selection>
      <:item as |item|>{{item.name}}</:item>
    </DSelect>
  </template>
}

const TRIGGER_INPUT = ".d-combobox__trigger [role='combobox']";

module("Integration | ui-kit | select | DSelect multi flip", function (hooks) {
  setupRenderingTest(hooks);

  test("the multi trigger is an inline combobox present before opening", async function (assert) {
    await render(<template><MultiHost /></template>);

    // Multi is a typeahead, so the trigger itself hosts the query input rather than
    // holding chips beside an expand button.
    assert
      .dom(TRIGGER_INPUT)
      .exists("the multi trigger hosts an inline combobox input")
      .hasAttribute("aria-autocomplete", "list");
    assert.dom("[role='listbox']").doesNotExist("closed on render");
  });

  test("typing in the inline input filters the list and drives the highlight (keyboard-alive)", async function (assert) {
    await render(<template><MultiHost /></template>);

    // The keyboard path dies silently if the trigger holds no filter input: filterInput is
    // null, so dRovingFocus gets no controllerElement and typing neither filters nor
    // highlights, with no error anywhere.
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
    assert.dom(TRIGGER_INPUT).hasValue("", "the query is reset after the add");
    assert.strictEqual(
      document.activeElement,
      find(TRIGGER_INPUT),
      "focus stays in the query input across the add"
    );
    assert
      .dom("[role='option'][aria-selected='true']")
      .hasText("Banana", "the picked row stays in the list, flagged selected");
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
    // Typing in the inline input is the open affordance for multi.
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

  const REMOVE = ".d-combobox__chip-remove";

  test("ArrowLeft at the start of the query enters the chip group; chips are not tab stops", async function (assert) {
    await render(<template><MultiHost @value={{array 1 2}} /></template>);

    const input = find(TRIGGER_INPUT);
    input.focus();
    // An empty query means the caret is at position 0.
    await triggerKeyEvent(input, "keydown", "ArrowLeft");

    const buttons = findAll(REMOVE);
    assert.strictEqual(
      document.activeElement,
      buttons[buttons.length - 1],
      "focus enters at the chip nearest the input (the last one)"
    );
    buttons.forEach((button) =>
      assert
        .dom(button)
        .hasAttribute(
          "tabindex",
          "-1",
          "every chip remove button is out of the tab order — the input is the sole tab stop"
        )
    );
  });

  test("arrows move between chips; ArrowRight past the last returns focus to the input", async function (assert) {
    await render(<template><MultiHost @value={{array 1 2}} /></template>);

    const input = find(TRIGGER_INPUT);
    input.focus();
    await triggerKeyEvent(input, "keydown", "ArrowLeft");

    const buttons = findAll(REMOVE);
    assert.strictEqual(
      document.activeElement,
      buttons[1],
      "entered on the last chip"
    );

    await triggerKeyEvent(buttons[1], "keydown", "ArrowLeft");
    assert.strictEqual(
      document.activeElement,
      buttons[0],
      "ArrowLeft moves to the previous chip"
    );

    await triggerKeyEvent(buttons[0], "keydown", "ArrowRight");
    assert.strictEqual(
      document.activeElement,
      buttons[1],
      "ArrowRight moves to the next chip"
    );

    await triggerKeyEvent(buttons[1], "keydown", "ArrowRight");
    assert.strictEqual(
      document.activeElement,
      input,
      "ArrowRight off the input-side edge returns focus to the query input"
    );
  });

  test("ArrowLeft at the first chip stays in the group", async function (assert) {
    await render(<template><MultiHost @value={{array 1 2}} /></template>);

    const input = find(TRIGGER_INPUT);
    input.focus();
    await triggerKeyEvent(input, "keydown", "ArrowLeft");

    const buttons = findAll(REMOVE);
    await triggerKeyEvent(buttons[1], "keydown", "ArrowLeft");
    assert.strictEqual(document.activeElement, buttons[0], "on the first chip");

    await triggerKeyEvent(buttons[0], "keydown", "ArrowLeft");
    assert.strictEqual(
      document.activeElement,
      buttons[0],
      "ArrowLeft at the left edge does not leave the group"
    );
  });

  test("Backspace on a focused chip removes it and moves focus to the previous chip", async function (assert) {
    await render(<template><MultiHost @value={{array 1 2 3}} /></template>);

    const input = find(TRIGGER_INPUT);
    input.focus();
    await triggerKeyEvent(input, "keydown", "ArrowLeft");
    // Enter on the last chip, step to the middle one (Banana).
    await triggerKeyEvent(findAll(REMOVE)[2], "keydown", "ArrowLeft");
    // The accessible name leads with the item label, then the removal hint.
    const labelledby = document.activeElement
      .getAttribute("aria-labelledby")
      .split(" ");
    assert.true(
      labelledby[0].endsWith("-label"),
      "the chip announces the item before the removal hint"
    );

    await triggerKeyEvent(findAll(REMOVE)[1], "keydown", "Backspace");

    assert
      .dom(".d-combobox__chip")
      .exists({ count: 2 }, "the focused chip is removed");
    assert.dom(".d-combobox__chip-label").exists({ count: 2 });
    const buttons = findAll(REMOVE);
    assert.strictEqual(
      document.activeElement,
      buttons[0],
      "focus moves to the previous chip (Apple)"
    );
  });

  test("Delete on a focused chip removes it", async function (assert) {
    await render(<template><MultiHost @value={{array 1 2}} /></template>);

    const input = find(TRIGGER_INPUT);
    input.focus();
    await triggerKeyEvent(input, "keydown", "ArrowLeft");
    await triggerKeyEvent(findAll(REMOVE)[1], "keydown", "Delete");

    assert
      .dom(".d-combobox__chip")
      .exists({ count: 1 }, "Delete removes the focused chip");
  });

  test("removing the only chip via the keyboard returns focus to the input", async function (assert) {
    await render(<template><MultiHost @value={{array 1}} /></template>);

    const input = find(TRIGGER_INPUT);
    input.focus();
    await triggerKeyEvent(input, "keydown", "ArrowLeft");
    await triggerKeyEvent(findAll(REMOVE)[0], "keydown", "Backspace");

    assert.dom(".d-combobox__chip").doesNotExist("the last chip is removed");
    assert.strictEqual(
      document.activeElement,
      find(TRIGGER_INPUT),
      "focus falls back to the query input when no chip remains"
    );
  });

  test("Escape while a chip is focused closes the menu, leaving focus on the chip", async function (assert) {
    await render(<template><MultiHost @value={{array 1 2}} /></template>);

    const input = find(TRIGGER_INPUT);
    input.focus();
    // Open the overlay, then move focus onto a chip.
    await triggerKeyEvent(input, "keydown", "ArrowDown");
    assert.dom("[role='listbox']").exists("the menu is open");
    await triggerKeyEvent(input, "keydown", "ArrowLeft");
    assert
      .dom(document.activeElement)
      .hasClass("d-combobox__chip-remove", "focus entered the chips");

    await triggerKeyEvent(findAll(REMOVE)[1], "keydown", "Escape");

    // float-kit owns Escape via a document-level capture listener that closes the menu;
    // focus stays on the chip, which is still arrow-navigable with the menu closed.
    assert.dom("[role='listbox']").doesNotExist("Escape closes the menu");
    assert
      .dom(document.activeElement)
      .hasClass(
        "d-combobox__chip-remove",
        "focus stays on the chip after the menu closes"
      );
  });

  test("ArrowDown from a focused chip moves focus to the input and opens the menu", async function (assert) {
    await render(<template><MultiHost @value={{array 1 2}} /></template>);

    const input = find(TRIGGER_INPUT);
    input.focus();
    // Enter the chips with the menu closed (ArrowLeft from the empty query).
    await triggerKeyEvent(input, "keydown", "ArrowLeft");
    assert
      .dom(document.activeElement)
      .hasClass("d-combobox__chip-remove", "focus is on a chip");
    assert.dom("[role='listbox']").doesNotExist("the menu is closed");

    // ArrowDown is the "go to the options" gesture: it jumps to the input (which owns the
    // aria-activedescendant highlight) and opens the list — the reopen path after Escape.
    await triggerKeyEvent(findAll(REMOVE)[1], "keydown", "ArrowDown");

    assert.dom("[role='listbox']").exists("ArrowDown opens the menu");
    assert.strictEqual(
      document.activeElement,
      find(TRIGGER_INPUT),
      "focus moves to the query input"
    );
    assert
      .dom("[role='option'].--active")
      .exists("the first option is highlighted for aria-activedescendant");
  });

  test("the query input advertises the chip-navigation hint via aria-describedby", async function (assert) {
    await render(<template><MultiHost @value={{array 1}} /></template>);

    assert
      .dom(TRIGGER_INPUT)
      .hasAttribute(
        "aria-describedby",
        /.+/,
        "the input names a describedby target while chips exist"
      );
    const hintId = find(TRIGGER_INPUT).getAttribute("aria-describedby");
    assert
      .dom(`#${hintId}`)
      .exists("the hint element is present")
      .hasText(
        "Press Left arrow to reach selected items.",
        "the hint tells keyboard users how to reach the chips"
      );
  });

  test("ArrowLeft with a non-empty query does not enter the chips", async function (assert) {
    await render(<template><MultiHost @value={{array 1}} /></template>);

    // A typed query puts the caret at the end (position > 0), so ArrowLeft is a caret move.
    await fillIn(TRIGGER_INPUT, "x");
    await triggerKeyEvent(TRIGGER_INPUT, "keydown", "ArrowLeft");

    assert.strictEqual(
      document.activeElement,
      find(TRIGGER_INPUT),
      "ArrowLeft mid-query keeps the caret in the input"
    );
  });

  test("ArrowLeft with no selection is a no-op", async function (assert) {
    await render(<template><MultiHost /></template>);

    const input = find(TRIGGER_INPUT);
    input.focus();
    await triggerKeyEvent(input, "keydown", "ArrowLeft");

    assert.dom(".d-combobox__chip").doesNotExist("no chips to enter");
    assert.strictEqual(
      document.activeElement,
      input,
      "ArrowLeft with an empty control does nothing"
    );
  });

  test("a composing ArrowLeft does not enter the chips", async function (assert) {
    await render(<template><MultiHost @value={{array 1 2}} /></template>);

    const input = find(TRIGGER_INPUT);
    input.focus();
    // Mid-IME composition the internal handler does not shield ArrowLeft, so the entry
    // guard must be `!event.isComposing` — otherwise focus would jump out of the input.
    input.dispatchEvent(
      new KeyboardEvent("keydown", {
        key: "ArrowLeft",
        isComposing: true,
        bubbles: true,
        cancelable: true,
      })
    );
    await settled();

    assert.strictEqual(
      document.activeElement,
      input,
      "a composing ArrowLeft keeps focus in the input"
    );
  });
});
