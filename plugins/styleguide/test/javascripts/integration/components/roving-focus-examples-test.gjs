import {
  click,
  findAll,
  render,
  settled,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import RovingFocusAdjacentGroupsExample from "discourse/plugins/styleguide/discourse/components/examples/molecules/roving-focus/adjacent-groups";
import RovingFocusComboboxExample from "discourse/plugins/styleguide/discourse/components/examples/molecules/roving-focus/combobox";
import RovingFocusListboxExample from "discourse/plugins/styleguide/discourse/components/examples/molecules/roving-focus/listbox";
import RovingFocusMultiSelectExample from "discourse/plugins/styleguide/discourse/components/examples/molecules/roving-focus/multi-select";
import RovingFocusRadioGroupExample from "discourse/plugins/styleguide/discourse/components/examples/molecules/roving-focus/radio-group";
import RovingFocusRemovableTagsExample from "discourse/plugins/styleguide/discourse/components/examples/molecules/roving-focus/removable-tags";
import RovingFocusToolbarExample from "discourse/plugins/styleguide/discourse/components/examples/molecules/roving-focus/toolbar";
import RovingFocusTreeExample from "discourse/plugins/styleguide/discourse/components/examples/molecules/roving-focus/tree";

/**
 * The tier-1 conformance fixtures are plain semantic HTML, so anything that fails here is the
 * modifier rather than a component wrapped around it.
 */

function pressKey(element, key) {
  const event = new KeyboardEvent("keydown", {
    key,
    bubbles: true,
    cancelable: true,
  });
  element.dispatchEvent(event);
  return event;
}

function labels(selector) {
  return findAll(selector).map((el) => el.textContent.trim());
}

function tabStop() {
  return findAll(".roving-demo__item").find(
    (el) => el.getAttribute("tabindex") === "0"
  );
}

module(
  "Integration | Component | roving-focus examples | toolbar",
  function (hooks) {
    setupRenderingTest(hooks);

    test("enters on the first control", async function (assert) {
      await render(<template><RovingFocusToolbarExample /></template>);

      assert
        .dom(tabStop())
        .hasText(
          "Bold",
          "the toolbar convention is the first control unconditionally"
        );
    });

    test("a pointer press moves the tab stop it lands on", async function (assert) {
      await render(<template><RovingFocusToolbarExample /></template>);

      await click(findAll(".roving-demo__item")[1]);

      assert
        .dom(findAll(".roving-demo__item")[1])
        .hasAttribute(
          "aria-pressed",
          "true",
          "the native button activated on its own"
        );
      assert
        .dom(tabStop())
        .hasText(
          "Italic",
          "so Tab out and back returns to where the reader last was, not to where the cursor was seeded"
        );
    });

    test("arrows walk the bar, telling the two spellings of disabled apart", async function (assert) {
      await render(<template><RovingFocusToolbarExample /></template>);

      const first = findAll(".roving-demo__item")[0];
      first.focus();

      const visited = [document.activeElement.textContent.trim()];
      for (let i = 0; i < 5; i++) {
        await triggerKeyEvent(document.activeElement, "keydown", "ArrowRight");
        visited.push(document.activeElement.textContent.trim());
      }

      assert.deepEqual(
        visited,
        ["Bold", "Italic", "Underline", "Copy", "Paste", "Authoring practices"],
        "Cut is skipped because the platform will not focus a disabled button, while Paste stays reachable so it can be discovered"
      );
    });

    test("the reachable disabled command is still not operable", async function (assert) {
      await render(<template><RovingFocusToolbarExample /></template>);

      const paste = findAll(".roving-demo__item").find(
        (el) => el.textContent.trim() === "Paste"
      );
      paste.focus();

      const event = new KeyboardEvent("keydown", {
        key: "Enter",
        bubbles: true,
        cancelable: true,
      });
      paste.dispatchEvent(event);

      assert.false(
        event.defaultPrevented,
        "the modifier declines to activate it, so nothing consumes the key on its behalf"
      );
    });

    test("End and Home reach the ends of the bar", async function (assert) {
      await render(<template><RovingFocusToolbarExample /></template>);

      findAll(".roving-demo__item")[0].focus();

      await triggerKeyEvent(document.activeElement, "keydown", "End");
      assert
        .dom(document.activeElement)
        .hasText("Authoring practices", "End reaches the last navigable item");

      await triggerKeyEvent(document.activeElement, "keydown", "Home");
      assert
        .dom(document.activeElement)
        .hasText("Bold", "Home reaches the first");
    });

    test("Space is left to the native button", async function (assert) {
      await render(<template><RovingFocusToolbarExample /></template>);

      const first = findAll(".roving-demo__item")[0];
      first.focus();

      const event = new KeyboardEvent("keydown", {
        key: " ",
        bubbles: true,
        cancelable: true,
      });
      first.dispatchEvent(event);

      assert.false(
        event.defaultPrevented,
        "no onActivate is passed, so the modifier does not claim Space and the button keeps its own activation"
      );
    });

    test("the separator states its orientation", async function (assert) {
      await render(<template><RovingFocusToolbarExample /></template>);

      assert
        .dom(".roving-demo__separator")
        .hasAttribute(
          "aria-orientation",
          "vertical",
          "a separator announces horizontal unless told otherwise, and this one stands upright"
        );
    });
  }
);

module(
  "Integration | Component | roving-focus examples | tree",
  function (hooks) {
    setupRenderingTest(hooks);

    test("the cursor covers only the rows that are visible", async function (assert) {
      await render(<template><RovingFocusTreeExample @dir="ltr" /></template>);

      assert.deepEqual(
        labels(".roving-demo__row"),
        ["Components", "Button", "Select", "Modifiers"],
        "the collapsed parent contributes no rows"
      );

      const rows = findAll(".roving-demo__row");
      rows[0].focus();
      await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");

      assert
        .dom(document.activeElement)
        .hasText("Button", "the next visible row takes the cursor");
    });

    test("collapsing a parent takes its children out of the sequence", async function (assert) {
      await render(<template><RovingFocusTreeExample @dir="ltr" /></template>);

      const parent = findAll(".roving-demo__row")[0];
      parent.focus();
      await triggerKeyEvent(parent, "keydown", "ArrowLeft");

      assert.deepEqual(
        labels(".roving-demo__row"),
        ["Components", "Modifiers"],
        "the children are gone"
      );

      await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");
      assert
        .dom(document.activeElement)
        .hasText("Modifiers", "the cursor steps to what is left");
    });

    test("the cross-axis keys mirror under rtl", async function (assert) {
      await render(<template><RovingFocusTreeExample @dir="rtl" /></template>);

      const parent = findAll(".roving-demo__row")[0];
      parent.focus();
      assert
        .dom(parent)
        .hasAttribute("aria-expanded", "true", "it starts expanded");

      await triggerKeyEvent(parent, "keydown", "ArrowRight");
      assert
        .dom(findAll(".roving-demo__row")[0])
        .hasAttribute(
          "aria-expanded",
          "false",
          "the arrow pointing away from the children closes them, which is ArrowRight here"
        );

      await triggerKeyEvent(
        findAll(".roving-demo__row")[0],
        "keydown",
        "ArrowLeft"
      );
      assert
        .dom(findAll(".roving-demo__row")[0])
        .hasAttribute(
          "aria-expanded",
          "true",
          "and the one pointing at them opens them, without the example resolving direction itself"
        );
    });

    test("the forward arrow steps into an open parent", async function (assert) {
      await render(<template><RovingFocusTreeExample @dir="ltr" /></template>);

      const parent = findAll(".roving-demo__row")[0];
      parent.focus();
      await triggerKeyEvent(parent, "keydown", "ArrowRight");

      assert
        .dom(document.activeElement)
        .hasText(
          "Button",
          "an open parent has nothing left to open, so forward reaches its first child"
        );
      assert
        .dom(findAll(".roving-demo__row")[0])
        .hasAttribute(
          "aria-expanded",
          "true",
          "and stepping in is not a toggle"
        );
    });

    test("the backward arrow returns a child to its parent", async function (assert) {
      await render(<template><RovingFocusTreeExample @dir="ltr" /></template>);

      const child = findAll(".roving-demo__row")[1];
      child.focus();
      await triggerKeyEvent(child, "keydown", "ArrowLeft");

      assert
        .dom(document.activeElement)
        .hasText(
          "Components",
          "a child has nothing to close, so backward climbs to the parent"
        );
      assert
        .dom(findAll(".roving-demo__row")[0])
        .hasAttribute(
          "aria-expanded",
          "true",
          "and climbing does not collapse on the way"
        );
    });
  }
);

module(
  "Integration | Component | roving-focus examples | listbox",
  function (hooks) {
    setupRenderingTest(hooks);

    test("enters on the option already chosen, not the first", async function (assert) {
      await render(<template><RovingFocusListboxExample /></template>);

      const seeded = findAll(".roving-demo__option").find(
        (el) => el.getAttribute("tabindex") === "0"
      );

      assert
        .dom(seeded)
        .hasAttribute(
          "data-option-id",
          "banana",
          "a listbox returns a reader to their own choice, which is the opposite of the toolbar convention"
        );
    });

    test("typing matches the name, and the decorative count is not part of it", async function (assert) {
      await render(<template><RovingFocusListboxExample /></template>);

      const rows = findAll(".roving-demo__option");
      rows[0].focus();

      pressKey(document.activeElement, "c");
      await settled();
      assert
        .dom(document.activeElement)
        .hasAttribute(
          "data-option-id",
          "cherry",
          "one character finds the first C"
        );

      const digit = pressKey(document.activeElement, "1");
      await settled();
      assert
        .dom(document.activeElement)
        .hasAttribute(
          "data-option-id",
          "cherry",
          "the counts belong to the text but not to any name, so a digit matches nothing"
        );
      assert.false(digit.defaultPrevented, "and the key is not consumed");
    });

    test("a second character narrows within the shared initial", async function (assert) {
      await render(<template><RovingFocusListboxExample /></template>);

      findAll(".roving-demo__option")[0].focus();

      pressKey(document.activeElement, "a");
      pressKey(document.activeElement, "p");
      await settled();

      assert
        .dom(document.activeElement)
        .hasAttribute(
          "data-option-id",
          "apricot",
          "ap passes over Apple, which only matches the first character"
        );
    });
  }
);

module(
  "Integration | Component | roving-focus examples | radio group",
  function (hooks) {
    setupRenderingTest(hooks);

    test("enters on the checked member", async function (assert) {
      await render(<template><RovingFocusRadioGroupExample /></template>);

      const seeded = findAll(".roving-demo__radio").find(
        (el) => el.getAttribute("tabindex") === "0"
      );

      assert
        .dom(seeded)
        .hasAttribute(
          "data-choice-id",
          "center",
          "aria-checked is the radio group spelling, and seeding has to read it"
        );
    });

    test("the choice follows the cursor", async function (assert) {
      await render(<template><RovingFocusRadioGroupExample /></template>);

      const center = findAll(".roving-demo__radio")[1];
      center.focus();
      await triggerKeyEvent(center, "keydown", "ArrowRight");

      assert
        .dom(document.activeElement)
        .hasAttribute("data-choice-id", "right", "the cursor moved");
      assert
        .dom(document.activeElement)
        .hasAttribute(
          "aria-checked",
          "true",
          "and the choice came with it, which is what this pattern expects"
        );
    });

    test("the vertical arrows move the choice too", async function (assert) {
      await render(<template><RovingFocusRadioGroupExample /></template>);

      const center = findAll(".roving-demo__radio")[1];
      center.focus();
      await triggerKeyEvent(center, "keydown", "ArrowDown");

      assert
        .dom(document.activeElement)
        .hasAttribute(
          "data-choice-id",
          "right",
          "the pattern requires both arrow pairs, whatever the visual axis"
        );
      assert
        .dom(document.activeElement)
        .hasAttribute(
          "aria-checked",
          "true",
          "and the choice follows here too"
        );
    });

    test("the arrows wrap at the ends", async function (assert) {
      await render(<template><RovingFocusRadioGroupExample /></template>);

      const center = findAll(".roving-demo__radio")[1];
      center.focus();
      await triggerKeyEvent(center, "keydown", "ArrowRight");
      await triggerKeyEvent(document.activeElement, "keydown", "ArrowRight");

      assert
        .dom(document.activeElement)
        .hasAttribute(
          "data-choice-id",
          "left",
          "past the last member the pattern comes back around rather than stopping"
        );
      assert
        .dom(document.activeElement)
        .hasAttribute("aria-checked", "true", "with the choice still attached");
    });
  }
);

module(
  "Integration | Component | roving-focus examples | removable tags",
  function (hooks) {
    setupRenderingTest(hooks);

    test("removing the focused tag hands the cursor to the next one", async function (assert) {
      await render(<template><RovingFocusRemovableTagsExample /></template>);

      const tags = findAll(".roving-demo__tag");
      assert.strictEqual(tags.length, 4, "four to begin with");

      tags[1].focus();
      await click(tags[1]);

      assert.strictEqual(
        findAll(".roving-demo__tag").length,
        3,
        "the tag is gone"
      );
      assert
        .dom(document.activeElement)
        .hasText(
          "Release",
          "focus followed to what took its place rather than falling to the page"
        );
    });

    test("removing the last tag hands the cursor backwards", async function (assert) {
      await render(<template><RovingFocusRemovableTagsExample /></template>);

      const tags = findAll(".roving-demo__tag");
      const last = tags[tags.length - 1];
      last.focus();
      await click(last);

      assert
        .dom(document.activeElement)
        .hasText(
          "Release",
          "there is nothing after it, so the item before takes the cursor"
        );
    });

    test("emptying the group leaves focus alone rather than guessing", async function (assert) {
      await render(<template><RovingFocusRemovableTagsExample /></template>);

      for (let i = 0; i < 4; i++) {
        const remaining = findAll(".roving-demo__tag");
        remaining[0].focus();
        await click(remaining[0]);
      }

      assert.strictEqual(
        findAll(".roving-demo__tag").length,
        0,
        "every tag is gone"
      );
      assert
        .dom(".roving-demo__reset")
        .exists("and the group offers a way back");
    });

    test("a tag's button says it removes", async function (assert) {
      await render(<template><RovingFocusRemovableTagsExample /></template>);

      assert
        .dom(findAll(".roving-demo__tag")[0])
        .hasAttribute(
          "aria-label",
          "Remove Design",
          "hearing only the tag's own name invites pressing Enter to inspect, which destroys it"
        );
    });
  }
);

module(
  "Integration | Component | roving-focus examples | combobox",
  function (hooks) {
    setupRenderingTest(hooks);

    test("the cursor moves while focus stays on the control", async function (assert) {
      await render(<template><RovingFocusComboboxExample /></template>);

      await click(".roving-demo__combobox-trigger");
      const trigger = document.querySelector(".roving-demo__combobox-trigger");

      assert
        .dom(".roving-demo__combobox-option.--active")
        .hasAttribute(
          "data-option-id",
          "weekly",
          "opening highlights the option already chosen"
        );

      await triggerKeyEvent(trigger, "keydown", "ArrowDown");

      assert
        .dom(".roving-demo__combobox-option.--active")
        .hasAttribute("data-option-id", "monthly", "the highlight moved");
      assert.strictEqual(
        document.activeElement,
        trigger,
        "and focus never left the control, which is the whole distinction from the other examples"
      );
      assert
        .dom(trigger)
        .hasAttribute(
          "aria-activedescendant",
          document.querySelector(".roving-demo__combobox-option.--active").id,
          "the control reports where the cursor is, since the browser cannot"
        );
    });

    test("Enter chooses the highlighted option", async function (assert) {
      await render(<template><RovingFocusComboboxExample /></template>);

      await click(".roving-demo__combobox-trigger");
      const trigger = document.querySelector(".roving-demo__combobox-trigger");
      await triggerKeyEvent(trigger, "keydown", "ArrowDown");
      await triggerKeyEvent(trigger, "keydown", "Enter");

      assert.dom(trigger).hasText("Monthly", "the choice is committed");
      assert
        .dom(".roving-demo__combobox-listbox")
        .doesNotExist("and the list closed");
    });

    test("the control can legally reach the option it points at", async function (assert) {
      const warn = sinon.stub(console, "warn");

      await render(<template><RovingFocusComboboxExample /></template>);
      await click(".roving-demo__combobox-trigger");
      await triggerKeyEvent(
        document.querySelector(".roving-demo__combobox-trigger"),
        "keydown",
        "ArrowDown"
      );

      assert.false(
        warn.calledWithMatch(/aria-activedescendant/),
        "aria-controls is one of the three permitted relationships, so no warning is raised"
      );
    });

    test("a pointer press chooses without stealing focus", async function (assert) {
      await render(<template><RovingFocusComboboxExample /></template>);

      await click(".roving-demo__combobox-trigger");
      const monthly = document.querySelector('[data-option-id="monthly"]');
      const mousedown = new MouseEvent("mousedown", {
        bubbles: true,
        cancelable: true,
        button: 0,
      });
      monthly.dispatchEvent(mousedown);

      assert.true(
        mousedown.defaultPrevented,
        "preventing the press is how the control keeps focus through the choice"
      );

      await click('[data-option-id="monthly"]');

      assert
        .dom(".roving-demo__combobox-trigger")
        .hasText("Monthly", "the click committed the option it landed on");
      assert
        .dom(".roving-demo__combobox-listbox")
        .doesNotExist("and the list closed");
    });

    test("Escape closes the popup", async function (assert) {
      await render(<template><RovingFocusComboboxExample /></template>);

      await click(".roving-demo__combobox-trigger");
      assert.dom(".roving-demo__combobox-listbox").exists("the list is open");

      await triggerKeyEvent(
        document.querySelector(".roving-demo__combobox-trigger"),
        "keydown",
        "Escape"
      );

      assert
        .dom(".roving-demo__combobox-listbox")
        .doesNotExist("dismissal is part of the pattern, not an extra");
    });

    test("the closed control opens from the arrows", async function (assert) {
      await render(<template><RovingFocusComboboxExample /></template>);

      await triggerKeyEvent(
        document.querySelector(".roving-demo__combobox-trigger"),
        "keydown",
        "ArrowDown"
      );

      assert
        .dom(".roving-demo__combobox-listbox")
        .exists("the arrow is an opening gesture on a collapsed control");
      assert
        .dom(".roving-demo__combobox-option.--active")
        .hasAttribute(
          "data-option-id",
          "weekly",
          "and the highlight enters on the option already chosen"
        );
    });

    test("aria-controls resolves exactly while the popup exists", async function (assert) {
      await render(<template><RovingFocusComboboxExample /></template>);

      assert
        .dom(".roving-demo__combobox-trigger")
        .doesNotHaveAttribute(
          "aria-controls",
          "collapsed, there is nothing for the reference to resolve to"
        );

      await click(".roving-demo__combobox-trigger");
      const listbox = document.querySelector(".roving-demo__combobox-listbox");

      assert
        .dom(".roving-demo__combobox-trigger")
        .hasAttribute(
          "aria-controls",
          listbox.id,
          "open, the reference names the listbox it actually controls"
        );
    });
  }
);

module(
  "Integration | Component | roving-focus examples | multi-select",
  function (hooks) {
    setupRenderingTest(hooks);

    test("entry lands on the row already chosen", async function (assert) {
      await render(<template><RovingFocusMultiSelectExample /></template>);

      const seeded = findAll(".roving-demo__option").find(
        (el) => el.getAttribute("tabindex") === "0"
      );

      assert
        .dom(findAll(".roving-demo__option")[0])
        .hasAttribute("aria-selected", "true", "the first row is chosen");
      assert
        .dom(seeded)
        .hasAttribute(
          "data-option-id",
          "keyboard",
          "the pattern returns a reader to their own selection rather than to the top of the list"
        );
    });

    test("arrows wrap past the last row", async function (assert) {
      await render(<template><RovingFocusMultiSelectExample /></template>);

      const rows = findAll(".roving-demo__option");
      rows[rows.length - 1].focus();
      await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");

      assert
        .dom(document.activeElement)
        .hasAttribute(
          "data-option-id",
          "keyboard",
          "passing the end returns to the top rather than stopping"
        );
    });
  }
);

module(
  "Integration | Component | roving-focus examples | adjacent groups",
  function (hooks) {
    setupRenderingTest(hooks);

    test("the filters are not in the tab sequence", async function (assert) {
      await render(<template><RovingFocusAdjacentGroupsExample /></template>);

      const tabbable = findAll(".roving-demo__filter").filter(
        (el) => el.getAttribute("tabindex") !== "-1"
      );

      assert.strictEqual(
        tabbable.length,
        0,
        "every filter is out of the tab order, so Tab reaches the field instead"
      );
    });

    test("an arrow from the start of the field steps into the filters", async function (assert) {
      await render(<template><RovingFocusAdjacentGroupsExample /></template>);

      const field = document.querySelector(".roving-demo__field");
      field.focus();
      field.setSelectionRange(0, 0);
      await triggerKeyEvent(field, "keydown", "ArrowLeft");

      assert
        .dom(document.activeElement)
        .hasText("Recent", "the nearest filter takes the cursor");
    });

    test("running off the end of the filters returns to the field", async function (assert) {
      await render(<template><RovingFocusAdjacentGroupsExample /></template>);

      const filters = findAll(".roving-demo__filter");
      const last = filters[filters.length - 1];
      last.focus();
      await triggerKeyEvent(last, "keydown", "ArrowRight");

      assert.strictEqual(
        document.activeElement,
        document.querySelector(".roving-demo__field"),
        "the boundary report is what sends it back, since the modifier does not know the field is there"
      );
    });

    test("the entry gesture mirrors under rtl", async function (assert) {
      await render(
        <template>
          <div dir="rtl"><RovingFocusAdjacentGroupsExample /></div>
        </template>
      );

      const field = document.querySelector(".roving-demo__field");
      field.focus();
      await triggerKeyEvent(field, "keydown", "ArrowLeft");

      assert.strictEqual(
        document.activeElement,
        field,
        "the left arrow is a live caret key here, so it must stay with the text"
      );

      await triggerKeyEvent(field, "keydown", "ArrowRight");

      assert
        .dom(document.activeElement)
        .hasClass(
          "roving-demo__filter",
          "the arrow pointing at the filters is the one that steps into them"
        );
    });
  }
);
