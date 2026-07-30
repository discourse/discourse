import { click, render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { findController } from "./assertions";

/**
 * A conformance suite for the ARIA combobox pattern, parameterised on a renderer.
 *
 * The test names are the `data-test-id` values from the W3C ARIA Authoring Practices Guide's own
 * regression suite (`w3c/aria-practices`, `test/tests/combobox_select-only.js` and
 * `combobox_autocomplete-list.js`). Those ids are keyed to rows in the APG's attributes and
 * keyboard-interaction tables, so naming tests after them makes our coverage auditable against the
 * spec rather than against our own idea of completeness.
 *
 * Parameterising on a renderer follows React Aria's `AriaMenuTests` shape: any implementation of the
 * pattern — a DSelect variant, a future picker, the legacy-bridge output — runs the identical
 * checklist rather than re-deriving its own.
 *
 * ## Capabilities are the point, not an escape hatch
 *
 * Every behaviour the APG specifies defaults to **on**. A renderer that does not have it must opt
 * out at its call site, where the opt-out reads as the documented gap it is. That is deliberate: a
 * missing test is invisible, whereas `opensOnHomeEnd: false` next to a comment is a finding someone
 * can act on. Do not add a capability to silence a failure you have not first explained.
 *
 * @param {object} config
 * @param {string} config.name - Appears in the module name, e.g. "DSelect select-only".
 * @param {object} config.renderer - Component rendering the widget under test. Rendered with no
 *   arguments, so it must supply its own items and state.
 * @param {object} [config.supports] - Capability declaration; see above.
 * @param {boolean} [config.supports.selectOnly] - The controller is not a text input. Select-only
 *   comboboxes take Enter/Space to open and Home/End to navigate; in an editable combobox those keys
 *   belong to the text field (Space types, Home/End move the caret) and must NOT be intercepted.
 * @param {boolean} [config.supports.filtering] - The controller is a text input that filters rows.
 * @param {boolean} [config.supports.multiple] - Multi-select, so `aria-multiselectable` applies.
 * @param {number} [config.supports.optionCount] - Rows the renderer provides. The boundary tests
 *   (End, no-wrap) need to know where the end is.
 * @param {boolean} [config.supports.typeToJump] - Printable characters move the cursor to a matching
 *   option (APG `printable-chars`).
 * @param {boolean} [config.supports.opensOnHomeEnd] - Home/End open the listbox onto the first/last
 *   option. APG requires this of a select-only combobox.
 * @param {boolean} [config.supports.closesOnAltArrowUp] - Alt+ArrowUp closes and commits.
 * @param {boolean} [config.supports.closesOnSelect] - Choosing a row closes the popup. False for
 *   multi-select, where the panel stays open across additions by design.
 */
export function ComboboxPatternTests({ name, renderer, supports = {} }) {
  const {
    selectOnly = false,
    filtering = false,
    multiple = false,
    typeToJump = false,
    opensOnHomeEnd = selectOnly,
    closesOnAltArrowUp = true,
    closesOnSelect = !multiple,
  } = supports;

  const optionCount = supports.optionCount ?? 3;
  const lastIndex = optionCount - 1;

  const Widget = renderer;

  /** Keys go to the element carrying role=combobox, which differs by variant. */
  const press = (key, modifiers = {}) =>
    triggerKeyEvent(findController(), "keydown", key, modifiers);

  const open = () => click(findController());

  module(`APG | combobox | ${name}`, function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(async function () {
      await render(<template><Widget /></template>);
    });

    /* Attributes */

    test("combobox-role", async function (assert) {
      assert
        .dom("[role='combobox']")
        .exists("the controller carries role=combobox");
    });

    test("listbox-role", async function (assert) {
      await open();
      assert.dom("[role='listbox']").exists("the popup carries role=listbox");
    });

    test("option-role", async function (assert) {
      await open();
      assert
        .dom("[role='listbox'] [role='option']")
        .exists({ count: optionCount }, "every row carries role=option");
    });

    test("combobox-aria-controls", async function (assert) {
      await open();
      assert.combobox().isLinkedToListbox();
    });

    test("combobox-aria-expanded (closed)", async function (assert) {
      assert.combobox().hasExpandedState(false);
      assert
        .combobox()
        .isNotLinkedToListbox("a closed combobox references no listbox");
    });

    test("combobox-aria-expanded (open)", async function (assert) {
      await open();
      assert.combobox().hasExpandedState(true);
    });

    test("combobox-aria-activedescendant", async function (assert) {
      await open();
      assert
        .combobox()
        .hasCursorOn(0, "opening puts the cursor on the first option");
    });

    test("option-aria-selected", async function (assert) {
      await open();
      assert
        .dom("[role='option'][aria-selected]")
        .exists("selection state is expressed on the options");
    });

    if (multiple) {
      test("listbox-aria-multiselectable", async function (assert) {
        await open();
        assert
          .dom("[role='listbox']")
          .hasAttribute(
            "aria-multiselectable",
            "true",
            "a multi-select listbox declares it"
          );
      });
    }

    test("option-aria-posinset-setsize", async function (assert) {
      await open();
      assert.combobox().hasContiguousPositions();
      assert.combobox().hasConsistentSetSize();
    });

    if (filtering) {
      test("combobox-aria-autocomplete", async function (assert) {
        assert
          .dom("[role='combobox']")
          .hasAttribute(
            "aria-autocomplete",
            "list",
            "a filtering combobox declares aria-autocomplete=list"
          );
      });
    }

    /* Opening */

    // ArrowDown/ArrowUp open every combobox. Enter and Space open only a select-only one — in an
    // editable combobox Space must reach the text field.
    const openingKeys = selectOnly
      ? ["Enter", " ", "ArrowDown", "ArrowUp"]
      : ["ArrowDown", "ArrowUp"];

    for (const key of openingKeys) {
      const label = key === " " ? "space" : key.toLowerCase();

      test(`combobox-key-${label} opens the listbox`, async function (assert) {
        await press(key);
        assert.dom("[role='listbox']").exists(`${label} opens the listbox`);
      });
    }

    if (opensOnHomeEnd) {
      test("combobox-key-home opens the listbox to the first option", async function (assert) {
        await press("Home");
        assert.dom("[role='listbox']").exists("Home opens the listbox");
        assert.combobox().hasCursorOn(0);
      });

      test("combobox-key-end opens the listbox to the last option", async function (assert) {
        await press("End");
        assert.dom("[role='listbox']").exists("End opens the listbox");
        assert.combobox().hasCursorOn(lastIndex);
      });
    }

    /* Navigating */

    test("listbox-key-down-arrow moves to the next option", async function (assert) {
      await open();
      await press("ArrowDown");
      assert.combobox().hasCursorOn(1);
    });

    test("listbox-key-up-arrow moves to the previous option", async function (assert) {
      await open();
      await press("ArrowDown");
      await press("ArrowUp");
      assert.combobox().hasCursorOn(0);
    });

    test("listbox-key-up-arrow does not wrap from the first option", async function (assert) {
      await open();
      await press("ArrowUp");
      assert.combobox().hasCursorOn(0, "the cursor stays on the first option");
    });

    // Home/End navigate the list only where they are not the text field's caret keys.
    if (selectOnly) {
      test("listbox-key-home moves to the first option", async function (assert) {
        await open();
        await press("End");
        await press("Home");
        assert.combobox().hasCursorOn(0);
      });

      test("listbox-key-end moves to the last option", async function (assert) {
        await open();
        await press("End");
        assert.combobox().hasCursorOn(lastIndex);
      });

      test("listbox-key-down-arrow does not wrap after the last option", async function (assert) {
        await open();
        await press("End");
        await press("ArrowDown");
        assert
          .combobox()
          .hasCursorOn(lastIndex, "the cursor stays on the last option");
      });
    }

    /* Closing */

    test("listbox-key-escape closes without selecting", async function (assert) {
      await open();
      await press("ArrowDown");
      await press("Escape");

      assert.dom("[role='listbox']").doesNotExist("Escape closes the listbox");
      assert
        .combobox()
        .isNotLinkedToListbox("closing drops the stale listbox reference");
    });

    if (closesOnSelect) {
      test("listbox-key-enter closes the listbox", async function (assert) {
        await open();
        await press("Enter");
        assert.dom("[role='listbox']").doesNotExist("Enter closes the listbox");
      });

      test("test-additional-behavior: clicking an option selects and closes", async function (assert) {
        await open();
        await click("[role='option']");
        assert
          .dom("[role='listbox']")
          .doesNotExist("choosing a row closes the listbox");
      });
    }

    if (closesOnAltArrowUp) {
      test("listbox-key-alt-up-arrow closes the listbox", async function (assert) {
        await open();
        await press("ArrowUp", { altKey: true });
        assert
          .dom("[role='listbox']")
          .doesNotExist("Alt+ArrowUp closes the listbox");
      });
    }

    /* Focus discipline */

    test("options never become tab stops", async function (assert) {
      await open();
      assert.combobox().hasSingleTabStop();
    });

    test("the cursor is dropped when the listbox closes", async function (assert) {
      await open();
      await press("Escape");
      assert.combobox().hasNoCursor();
    });

    /* Typeahead */

    if (typeToJump) {
      test("printable-chars move the cursor to a matching option", async function (assert) {
        await open();
        await press("b");
        assert
          .combobox()
          .hasCursorOn(1, "typing a character jumps to the matching row");
      });
    }

    /* Pointer */

    // Clicking the controller again closes only where the controller is not a text input; clicking
    // into a text field to place the caret must not dismiss the list.
    if (selectOnly) {
      test("test-additional-behavior: click opens and closes the listbox", async function (assert) {
        await open();
        assert.dom("[role='listbox']").exists("clicking opens the listbox");

        await click(findController());
        assert.dom("[role='listbox']").doesNotExist("clicking again closes it");
      });
    }
  });
}
