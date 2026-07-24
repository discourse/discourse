import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import {
  click,
  fillIn,
  find,
  findAll,
  focus,
  render,
  settled,
  triggerEvent,
  triggerKeyEvent,
  waitFor,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import DMenu from "discourse/float-kit/components/d-menu";
import { forceMobile } from "discourse/lib/mobile";
import { withPluginApi } from "discourse/lib/plugin-api";
import { clearCallbacks } from "discourse/select-kit/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { resetLegacyBridge } from "discourse/ui-kit/select/-internals/modify-select-kit-bridge";
import SelectItem from "discourse/ui-kit/select/-internals/select-item";
import DSelect from "discourse/ui-kit/select/d-select";
import SelectEngine from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

const ITEMS = [
  { id: 1, name: "Apple" },
  { id: 2, name: "Banana" },
  { id: 3, name: "Cherry pie" },
];

// A controlled host: it owns @value and updates it from @onChange, exactly as a
// consumer (or FormKit) does.
class Host extends Component {
  @tracked value = this.args.value ?? null;

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @items={{ITEMS}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @variant={{@variant}}
      @placeholder="Pick one"
      @identifier="test-select"
    >
      <:selection as |item|>{{item.name}}</:selection>
      <:item as |item|>{{item.name}}</:item>
    </DSelect>
  </template>
}

class DefaultHost extends Component {
  @tracked value = this.args.value ?? (this.args.multiple ? [] : null);

  get items() {
    return this.args.items ?? ITEMS;
  }

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @items={{this.items}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @variant={{@variant}}
      @multiple={{@multiple}}
      @labelField={{@labelField}}
      @placeholder="Pick one"
    />
  </template>
}

module("Integration | ui-kit | select | DSelect (layout)", function (hooks) {
  setupRenderingTest(hooks);

  test("trigger frame preserves the DOM structure across variants", async function (assert) {
    await render(
      <template>
        <DSelect class="frame-typeahead" @items={{ITEMS}} @value={{1}} />
        <DSelect
          class="frame-multi"
          @items={{ITEMS}}
          @value={{array 1 2}}
          @multiple={{true}}
        />
        <DSelect
          class="frame-button"
          @items={{ITEMS}}
          @value={{1}}
          @variant="button"
        />
        <DSelect
          class="frame-static"
          @items={{ITEMS}}
          @value={{1}}
          @variant="static"
        />
      </template>
    );

    const variants = [
      ["typeahead", ".frame-typeahead", ".d-combobox__input"],
      ["multi", ".frame-multi", ".d-combobox__chips"],
      ["button", ".frame-button", ".d-combobox__value"],
      ["static", ".frame-static", ".d-combobox__value"],
    ];

    for (const [name, triggerSelector, middleSelector] of variants) {
      const trigger = find(triggerSelector);
      const caret = find(`${triggerSelector} .d-combobox__caret`);

      assert
        .dom(`${triggerSelector} .d-combobox__caret`)
        .exists({ count: 1 }, `${name} renders exactly one caret`);
      assert.strictEqual(
        trigger.lastElementChild,
        caret,
        `${name} renders the caret as the trigger's last element child`
      );
      assert
        .dom(`${triggerSelector} > ${middleSelector}`)
        .exists(
          { count: 1 },
          `${name} keeps its variant middle as a direct trigger child`
        );
    }
  });

  test("empty variants use the same field height", async function (assert) {
    await render(
      <template>
        <DSelect class="layout-typeahead" @items={{ITEMS}} />
        <DSelect class="layout-button" @items={{ITEMS}} @variant="button" />
        <DSelect class="layout-static" @items={{ITEMS}} @variant="static" />
        <DSelect class="layout-multi" @items={{ITEMS}} @multiple={{true}} />
      </template>
    );

    const heights = [
      ".layout-typeahead.d-combobox__trigger",
      ".layout-button.d-combobox__trigger",
      ".layout-static.d-combobox__trigger",
      ".layout-multi.d-combobox__trigger",
    ].map((selector) => find(selector).getBoundingClientRect().height);

    assert.deepEqual(
      heights,
      Array(heights.length).fill(heights[0]),
      "every empty variant uses the typeahead field height"
    );

    const insets = [
      [".layout-typeahead.d-combobox__trigger", ".d-combobox__input"],
      [".layout-button.d-combobox__trigger", ".d-combobox__placeholder"],
      [".layout-static.d-combobox__trigger", ".d-combobox__placeholder"],
      [".layout-multi.d-combobox__trigger", ".d-combobox__input"],
    ].map(([triggerSelector, contentSelector]) => {
      const trigger = find(triggerSelector);
      const content = trigger.querySelector(contentSelector);
      return (
        content.getBoundingClientRect().left -
        trigger.getBoundingClientRect().left
      );
    });

    assert.deepEqual(
      insets,
      Array(insets.length).fill(insets[0]),
      "every empty variant uses the typeahead field inset"
    );

    const typeaheadInput = find(
      ".layout-typeahead.d-combobox__trigger .d-combobox__input"
    );
    const colors = [
      getComputedStyle(typeaheadInput, "::placeholder").color,
      getComputedStyle(
        find(".layout-button.d-combobox__trigger .d-combobox__placeholder")
      ).color,
      getComputedStyle(
        find(".layout-static.d-combobox__trigger .d-combobox__placeholder")
      ).color,
      getComputedStyle(
        find(".layout-multi.d-combobox__trigger .d-combobox__input"),
        "::placeholder"
      ).color,
    ];

    assert.deepEqual(
      colors,
      Array(colors.length).fill(colors[0]),
      "every empty variant uses the typeahead placeholder color"
    );
  });

  test("the dropdown content fills the matched trigger width", async function (assert) {
    await render(
      <template>
        <div style="width: 24rem;">
          <DSelect @items={{ITEMS}} @variant="button" />
        </div>
      </template>
    );
    await click(".d-combobox__trigger");

    const triggerWidth = find(".d-combobox__trigger").getBoundingClientRect()
      .width;

    const innerContent = find(".fk-d-menu__inner-content");
    assert.strictEqual(
      innerContent.getBoundingClientRect().width,
      triggerWidth,
      "the visible dropdown surface fills the trigger width"
    );
    assert.true(
      find(".d-combobox__panel").getBoundingClientRect().width >=
        triggerWidth - 2,
      "the dropdown panel fills the surface within its border"
    );
  });
});

module("Integration | ui-kit | select | DSelect (typeahead)", function (hooks) {
  setupRenderingTest(hooks);

  test("the trigger is a combobox input, present before opening", async function (assert) {
    await render(<template><Host /></template>);

    assert
      .dom("[role='combobox']")
      .exists("the trigger itself is the combobox input")
      .hasAttribute("aria-autocomplete", "list")
      .hasAttribute("aria-expanded", "false", "closed until opened")
      .hasAttribute(
        "aria-label",
        "Options",
        "the input has an accessible name"
      );
    assert
      .dom("[role='combobox']")
      .hasAttribute(
        "placeholder",
        "Pick one",
        "the input shows the placeholder"
      );
    assert.dom("[role='listbox']").doesNotExist("closed on render");
  });

  test("the empty trigger renders as one input field", async function (assert) {
    await render(<template><Host /></template>);

    assert
      .dom("[role='combobox']")
      .hasAttribute(
        "placeholder",
        "Pick one",
        "the input owns the placeholder"
      );
    assert
      .dom(".d-combobox__placeholder")
      .doesNotExist("no separate placeholder sits beside the input");

    const inputStyle = getComputedStyle(find("[role='combobox']"));
    assert.strictEqual(
      inputStyle.borderTopStyle,
      "none",
      "the inner input does not draw a second border"
    );
    assert.strictEqual(
      inputStyle.backgroundColor,
      "rgba(0, 0, 0, 0)",
      "the inner input does not draw a second background"
    );
    assert.strictEqual(
      inputStyle.marginBottom,
      "0px",
      "the inner input does not enlarge the composite field"
    );
  });

  test("falls back to the label field when presentation blocks are omitted", async function (assert) {
    await render(<template><DefaultHost @value={{2}} /></template>);

    assert
      .dom("[role='combobox']")
      .hasValue("Banana", "the selected label is the input value");

    await focus("[role='combobox']");
    const input = find("[role='combobox']");
    assert.deepEqual(
      [input.selectionStart, input.selectionEnd],
      [0, 6],
      "focusing selects the fallback label"
    );

    await fillIn("[role='combobox']", "cherry");
    assert
      .dom("[role='option']")
      .exists({ count: 1 }, "the fallback input becomes the query")
      .hasText("Cherry pie", "options also fall back to the label field");

    await fillIn("[role='combobox']", "");
    assert
      .dom("[role='combobox']")
      .hasValue("", "an emptied query stays in editing mode");

    await triggerKeyEvent("[role='combobox']", "keydown", "Escape");
    assert
      .dom("[role='combobox']")
      .hasValue("Banana", "closing restores the selected label");
  });

  test("selects a numeric-id item from a string-bound value", async function (assert) {
    // A bound value often arrives as a string (site settings, query params) against
    // numeric option ids; it must still resolve and display the selection.
    await render(<template><DefaultHost @value="2" /></template>);

    assert
      .dom("[role='combobox']")
      .hasValue("Banana", "the string value '2' selects the numeric-id item");
  });

  test("renders and selects a @valueField list that has no id field", async function (assert) {
    const items = [
      { slug: "apple", name: "Apple" },
      { slug: "banana", name: "Banana" },
    ];

    await render(
      <template>
        <DSelect @items={{items}} @value="banana" @valueField="slug" />
      </template>
    );

    assert
      .dom("[role='combobox']")
      .hasValue("Banana", "the id-less selection resolves via @valueField");

    await click("[role='combobox']");
    assert
      .dom("[role='option']")
      .exists({ count: 2 }, "both id-less rows render (keyed by @valueField)");
    assert
      .dom("[role='option'][aria-selected='true']")
      .hasText("Banana", "the row matching @value is flagged selected");
  });

  test("custom blocks override label-field fallbacks independently", async function (assert) {
    const items = [
      { id: 1, title: "First" },
      { id: 2, title: "Second" },
    ];

    await render(
      <template>
        <DSelect
          @items={{items}}
          @value={{1}}
          @labelField="title"
          @placeholder="Pick one"
        >
          <:selection as |item|><strong>{{item.title}}</strong></:selection>
        </DSelect>
      </template>
    );

    assert
      .dom(".d-combobox__presentation strong")
      .hasText("First", "the supplied selection block wins");

    await click("[role='combobox']");
    assert
      .dom("[role='option']")
      .exists({ count: 2 }, "the omitted item block uses the fallback")
      .hasText("First", "the fallback reads the custom label field");
  });

  test("a custom selection stays replaced after the query is emptied", async function (assert) {
    await render(<template><Host @value={{1}} /></template>);

    await fillIn("[role='combobox']", "ban");
    await fillIn("[role='combobox']", "");

    assert
      .dom(".d-combobox__presentation")
      .doesNotExist("editing mode continues until the menu closes");

    await triggerKeyEvent("[role='combobox']", "keydown", "Escape");
    assert
      .dom(".d-combobox__presentation")
      .hasText("Apple", "closing restores the custom selection");
  });

  test("does not open on focus; opens on ArrowDown, on click, and on typing", async function (assert) {
    await render(<template><Host /></template>);

    await focus("[role='combobox']");
    assert.dom("[role='listbox']").doesNotExist("bare focus never opens");

    await triggerKeyEvent("[role='combobox']", "keydown", "ArrowDown");
    assert.dom("[role='listbox']").exists("ArrowDown opens");
    assert.dom("[role='combobox']").hasAttribute("aria-expanded", "true");

    await triggerKeyEvent("[role='combobox']", "keydown", "Escape");
    assert.dom("[role='listbox']").doesNotExist("Escape closes");

    await click("[role='combobox']");
    assert.dom("[role='listbox']").exists("click opens");
  });

  test("typing filters, and the query drives the list", async function (assert) {
    await render(<template><Host /></template>);

    await fillIn("[role='combobox']", "ban");
    assert.dom("[role='listbox']").exists("typing opens the list");
    assert.dom("[role='option']").exists({ count: 1 });
    assert.dom("[role='option']").hasText("Banana");

    // A term with a space must filter (the space isn't swallowed by keyboard nav).
    await fillIn("[role='combobox']", "cherry p");
    assert.dom("[role='option']").hasText("Cherry pie");
  });

  test("auto-highlights the first match and re-seeds as the query changes", async function (assert) {
    await render(<template><Host /></template>);

    await fillIn("[role='combobox']", "a");
    const active = document.querySelector("[role='option'].--active");
    assert.dom(active).hasText("Apple", "the first match is highlighted");
    assert
      .dom("[role='combobox']")
      .hasAttribute(
        "aria-activedescendant",
        active.id,
        "aria-activedescendant points at the highlighted option"
      );

    await fillIn("[role='combobox']", "cherry");
    assert
      .dom("[role='option'].--active")
      .hasText("Cherry pie", "the highlight re-seeds to the new first match");
  });

  test("Enter selects the highlighted option without an ArrowDown, and closes", async function (assert) {
    await render(<template><Host /></template>);
    await fillIn("[role='combobox']", "app");

    await triggerKeyEvent("[role='combobox']", "keydown", "Enter");

    assert.dom("[role='listbox']").doesNotExist("selecting closes the menu");
    assert.dom(".d-combobox__presentation").hasText("Apple");
  });

  test("focus stays in the input while navigating with the arrows", async function (assert) {
    await render(<template><Host /></template>);
    await fillIn("[role='combobox']", "");
    await triggerKeyEvent("[role='combobox']", "keydown", "ArrowDown");

    assert.strictEqual(
      document.activeElement.getAttribute("role"),
      "combobox",
      "the input keeps focus during navigation (active mode)"
    );
  });

  test("Escape resets the query so the next open starts clean", async function (assert) {
    await render(<template><Host /></template>);
    await fillIn("[role='combobox']", "ban");
    assert.dom("[role='option']").exists({ count: 1 });

    await triggerKeyEvent("[role='combobox']", "keydown", "Escape");
    await click("[role='combobox']");

    assert.dom("[role='combobox']").hasValue("", "the query was reset");
    assert.dom("[role='option']").exists({ count: 3 }, "the full list is back");
  });

  test("moving focus to another field (Tab-out) closes it", async function (assert) {
    await render(
      <template>
        <Host />
        <button type="button" class="outside">outside</button>
      </template>
    );
    await click("[role='combobox']");
    assert.dom("[role='listbox']").exists();

    // Focus moving to a focusable element outside the widget closes it. (A bare blur with
    // no outside focus target does not; a truly-outside pointer click is handled below.)
    await focus(".outside");
    assert.dom("[role='listbox']").doesNotExist("Tab-out closes");
  });

  test("clicking a non-focusable element outside closes it", async function (assert) {
    await render(
      <template>
        <Host />
        <div class="outside">outside</div>
      </template>
    );
    await click("[role='combobox']");
    assert.dom("[role='listbox']").exists();

    // close-on-click-outside listens for a document `pointerdown` (not `click`), matching
    // float-kit's own dismiss tests; our `untriggers=[]` config must not break it.
    await triggerEvent(".outside", "pointerdown");
    assert.dom("[role='listbox']").doesNotExist("click-outside closes");
  });

  test("pointer: clicking an option selects it and closes", async function (assert) {
    await render(<template><Host /></template>);
    await click("[role='combobox']");
    await click("[role='option'][aria-selected='false']");

    assert.dom("[role='listbox']").doesNotExist("selecting closes the menu");
    assert
      .dom(".d-combobox__presentation")
      .exists("the trigger shows the selection");
  });

  test("clicking anywhere on the trigger (caret/label) opens and focuses the input", async function (assert) {
    await render(<template><Host @value={{1}} /></template>);
    assert.dom(".d-combobox__presentation").hasText("Apple");

    // The whole trigger is the open target, not just the narrow input strip.
    await click(".d-combobox__caret");
    assert.dom("[role='listbox']").exists("clicking the caret opens the menu");
    assert.strictEqual(
      document.activeElement.getAttribute("role"),
      "combobox",
      "focus lands in the query input"
    );
  });

  test("clicking the trigger while open does not toggle it closed", async function (assert) {
    await render(<template><Host @value={{1}} /></template>);
    await click("[role='combobox']");
    assert.dom("[role='listbox']").exists();

    // Clicking a non-focusable trigger region (the caret) while open must not blur-close
    // or toggle it shut.
    await click(".d-combobox__caret");
    assert
      .dom("[role='listbox']")
      .exists("stays open after clicking the caret");
  });

  test("a preset value resolves to its label with no fetch (client source)", async function (assert) {
    await render(<template><Host @value={{2}} /></template>);
    assert
      .dom(".d-combobox__presentation")
      .hasText("Banana", "the saved id resolves from the client list");
  });

  test("marks the selected option with aria-selected", async function (assert) {
    await render(<template><Host @value={{1}} /></template>);
    await click("[role='combobox']");
    assert
      .dom("[role='option'][aria-selected='true']")
      .hasText("Apple", "the current value's option is aria-selected");
  });

  test("shows an empty status and never a role=alert for no matches", async function (assert) {
    await render(<template><Host /></template>);
    await fillIn("[role='combobox']", "zzzz");

    assert
      .dom(".d-combobox__empty[role='status']")
      .exists("polite empty status");
    assert
      .dom("[role='alert']")
      .doesNotExist("counts/empties are announced politely, never assertively");
  });

  test("mid-composition input does not open or filter (IME)", async function (assert) {
    await render(<template><Host /></template>);
    const input = document.querySelector("[role='combobox']");

    input.value = "ban";
    input.dispatchEvent(new InputEvent("input", { isComposing: true }));
    assert
      .dom("[role='listbox']")
      .doesNotExist("a half-composed query neither opens nor filters");

    input.dispatchEvent(new CompositionEvent("compositionend"));
    await triggerKeyEvent("[role='combobox']", "keydown", "ArrowDown");
    assert
      .dom("[role='option']")
      .exists({ count: 1 }, "committing the composition filters");
    assert.dom("[role='option']").hasText("Banana");
  });
});

module(
  "Integration | ui-kit | select | DSelect (typeahead, mobile)",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      forceMobile();
    });

    test("tapping the trigger opens a modal that hosts the focused query input", async function (assert) {
      await render(<template><Host /></template>);

      // On mobile the trigger holds no input of its own; tapping the trigger opens the modal.
      assert
        .dom(".d-combobox__trigger [role='combobox']")
        .doesNotExist("no query input in the closed mobile trigger");

      await click(".d-combobox__trigger");

      assert
        .dom(".fk-d-menu-modal [role='combobox']")
        .exists("the query input renders inside the modal");
      assert.strictEqual(
        document.activeElement.getAttribute("role"),
        "combobox",
        "the modal input is focused on open"
      );

      await fillIn(".fk-d-menu-modal [role='combobox']", "ban");
      assert.dom("[role='option']").exists({ count: 1 });
      assert.dom("[role='option']").hasText("Banana");
    });

    test("the closed trigger uses the default selection label", async function (assert) {
      await render(<template><DefaultHost @value={{2}} /></template>);

      assert
        .dom(".d-combobox__presentation")
        .hasText("Banana", "mobile has the same block-free fallback");
    });
  }
);

module(
  "Integration | ui-kit | select | DSelect (button variant)",
  function (hooks) {
    setupRenderingTest(hooks);

    test("opens into a WAI-ARIA combobox + listbox with wired ids", async function (assert) {
      await render(<template><Host @variant="button" /></template>);
      await click(".d-combobox__trigger");

      assert.dom("[role='combobox']").exists("the panel filter is a combobox");
      assert
        .dom("[role='combobox']")
        .hasAttribute("aria-autocomplete", "list")
        .hasAttribute("aria-expanded", "true");
      assert.dom("[role='listbox']").exists("results are a listbox");
      assert.dom("[role='option']").exists({ count: 3 }, "one option per item");

      const listboxId = document
        .querySelector("[role='listbox']")
        .getAttribute("id");
      assert
        .dom("[role='combobox']")
        .hasAttribute(
          "aria-controls",
          listboxId,
          "aria-controls points at the listbox"
        );
    });

    test("the trigger is a disclosure button that opens from the keyboard", async function (assert) {
      await render(<template><Host @variant="button" /></template>);

      // The button variant's in-panel filter is the combobox, so its trigger is a
      // role="button" disclosure (not a second combobox), focusable and keyboard-openable.
      assert
        .dom(".d-combobox__trigger")
        .hasAttribute("role", "button", "the trigger is a disclosure button")
        .hasAttribute("aria-haspopup", "listbox")
        .hasAttribute("tabindex", "0", "the trigger is focusable")
        .hasAttribute("aria-expanded", "false");

      await focus(".d-combobox__trigger");
      await triggerKeyEvent(".d-combobox__trigger", "keydown", "Enter");
      assert.dom("[role='listbox']").exists("Enter opens the list");
      assert.dom(".d-combobox__trigger").hasAttribute("aria-expanded", "true");
    });

    test("Space and click independently activate the disclosure", async function (assert) {
      await render(<template><Host @variant="button" /></template>);

      assert
        .dom(".d-combobox__trigger")
        .hasAttribute(
          "role",
          "button",
          "the disclosure role is on the trigger"
        );

      await focus(".d-combobox__trigger");
      await triggerKeyEvent(".d-combobox__trigger", "keydown", " ");
      assert.dom("[role='listbox']").exists("Space opens the disclosure");

      await triggerKeyEvent("[role='combobox']", "keydown", "Escape");
      assert.dom("[role='listbox']").doesNotExist("Escape closes it again");

      await click(".d-combobox__trigger");
      assert.dom("[role='listbox']").exists("click opens the disclosure");
    });

    test("filters as you type, and spaces reach the filter", async function (assert) {
      await render(<template><Host @variant="button" /></template>);
      await click(".d-combobox__trigger");

      await fillIn("[role='combobox']", "ban");
      assert.dom("[role='option']").exists({ count: 1 });
      assert.dom("[role='option']").hasText("Banana");

      await fillIn("[role='combobox']", "cherry p");
      assert.dom("[role='option']").hasText("Cherry pie");
    });

    test("keyboard: ArrowDown + Enter selects the highlighted option and closes", async function (assert) {
      await render(<template><Host @variant="button" /></template>);
      await click(".d-combobox__trigger");
      await fillIn("[role='combobox']", "app");

      await triggerKeyEvent("[role='combobox']", "keydown", "ArrowDown");
      await triggerKeyEvent("[role='combobox']", "keydown", "Enter");

      assert.dom("[role='listbox']").doesNotExist("selecting closes the menu");
      assert
        .dom(".d-combobox__value")
        .hasText("Apple", "the trigger shows the pick");
    });

    test("pointer: clicking an option selects it and closes", async function (assert) {
      await render(<template><Host @variant="button" /></template>);
      await click(".d-combobox__trigger");
      await click("[role='option'][aria-selected='false']");

      assert.dom("[role='listbox']").doesNotExist("selecting closes the menu");
      assert
        .dom(".d-combobox__value")
        .exists("the trigger shows the selection");
    });

    test("uses default labels when presentation blocks are omitted", async function (assert) {
      await render(
        <template><DefaultHost @variant="button" @value={{2}} /></template>
      );

      assert
        .dom(".d-combobox__value")
        .hasText("Banana", "the button trigger uses the selection fallback");

      await click(".d-combobox__trigger");
      assert
        .dom("[role='option']")
        .exists({ count: 3 }, "the block-free button renders every option")
        .hasText("Apple", "option rows use the item fallback");
    });
  }
);

module("Integration | ui-kit | select | DSelect (static)", function (hooks) {
  setupRenderingTest(hooks);

  test("the trigger itself is a select-only combobox (no filter input)", async function (assert) {
    await render(<template><Host @variant="static" /></template>);

    // WAI-ARIA Select-Only Combobox: the focusable trigger IS the combobox, so there is
    // no separate filter input; the role/haspopup/tabindex live on the trigger.
    assert
      .dom(".d-combobox__trigger")
      .hasAttribute("role", "combobox", "the trigger is the combobox")
      .hasAttribute("aria-haspopup", "listbox")
      .hasAttribute("tabindex", "0", "the trigger is focusable")
      .hasAttribute("aria-expanded", "false");
    assert
      .dom("input[role='combobox']")
      .doesNotExist("no filter input — the trigger is the combobox");

    await click(".d-combobox__trigger");

    assert.dom("[role='listbox']").exists();
    assert.dom("[role='option']").exists({ count: 3 });

    const listboxId = document.querySelector("[role='listbox']").id;
    assert
      .dom(".d-combobox__trigger")
      .hasAttribute("aria-expanded", "true")
      .hasAttribute(
        "aria-controls",
        listboxId,
        "aria-controls points at the open listbox"
      );

    await click("[role='option']");
    assert.dom("[role='listbox']").doesNotExist("selecting closes (single)");
    assert.dom(".d-combobox__value").hasText("Apple");
  });

  test("opens from the keyboard and keeps focus on the trigger", async function (assert) {
    await render(<template><Host @variant="static" /></template>);

    await focus(".d-combobox__trigger");
    await triggerKeyEvent(".d-combobox__trigger", "keydown", "ArrowDown");

    assert.dom("[role='listbox']").exists("ArrowDown opens the list");
    // Select-only combobox: focus stays on the trigger (active-descendant), never moves
    // into the listbox.
    assert
      .dom(".d-combobox__trigger")
      .isFocused("focus stays on the combobox trigger");
    assert
      .dom("[role='option'][tabindex='0']")
      .doesNotExist(
        "options are not roving tab stops (active-descendant mode)"
      );
  });

  test("keyboard opening activates the first option through aria-activedescendant", async function (assert) {
    await render(<template><Host @variant="static" /></template>);

    await focus(".d-combobox__trigger");
    await triggerKeyEvent(".d-combobox__trigger", "keydown", "Enter");

    const firstOptionId = find("[role='option']").id;
    assert
      .dom(".d-combobox__trigger")
      .hasAttribute(
        "aria-activedescendant",
        firstOptionId,
        "Enter activates the first option on open"
      );
    assert
      .dom("[role='option']")
      .hasClass("--active", "the active option has the visual active state");

    await triggerKeyEvent(".d-combobox__trigger", "keydown", "Escape");
    await triggerKeyEvent(".d-combobox__trigger", "keydown", "ArrowDown");

    assert
      .dom(".d-combobox__trigger")
      .hasAttribute(
        "aria-activedescendant",
        find("[role='option']").id,
        "ArrowDown also activates the first option on open"
      );
  });

  test("keyboard lifecycle gates aria-controls and restores trigger focus", async function (assert) {
    await render(<template><Host @variant="static" /></template>);

    assert
      .dom(".d-combobox__trigger")
      .hasAttribute("role", "combobox", "the trigger is the select controller")
      .doesNotHaveAttribute(
        "aria-controls",
        "a closed trigger does not reference an unrendered listbox"
      );

    await focus(".d-combobox__trigger");
    await triggerKeyEvent(".d-combobox__trigger", "keydown", "Enter");

    const listbox = find("[role='listbox']");
    assert
      .dom(".d-combobox__trigger")
      .isFocused("Enter leaves DOM focus on the trigger")
      .hasAttribute(
        "aria-controls",
        listbox.id,
        "the open trigger references the rendered listbox"
      );
    assert
      .dom("[role='option'][tabindex='0']")
      .doesNotExist("listbox options never become tab stops");

    await triggerKeyEvent(".d-combobox__trigger", "keydown", "Escape");
    assert.dom("[role='listbox']").doesNotExist("Escape closes the listbox");
    assert
      .dom(".d-combobox__trigger")
      .isFocused("closing restores focus to the trigger")
      .doesNotHaveAttribute(
        "aria-controls",
        "closing removes the stale listbox reference"
      );

    await triggerKeyEvent(".d-combobox__trigger", "keydown", "ArrowDown");
    assert.dom("[role='listbox']").exists("ArrowDown reopens the listbox");
    assert
      .dom(".d-combobox__trigger")
      .isFocused("ArrowDown also leaves focus on the trigger");
  });

  test("uses default labels when presentation blocks are omitted", async function (assert) {
    await render(
      <template><DefaultHost @variant="static" @value={{2}} /></template>
    );

    assert
      .dom(".d-combobox__value")
      .hasText("Banana", "the static trigger uses the selection fallback");

    await click(".d-combobox__trigger");
    assert
      .dom("[role='option']")
      .exists({ count: 3 }, "the block-free static select renders every option")
      .hasText("Apple", "option rows use the item fallback");
  });
});

module(
  "Integration | ui-kit | select | DSelect (static, mobile)",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      forceMobile();
    });

    test("opening moves DOM focus into the modal's roving option list", async function (assert) {
      await render(<template><Host @variant="static" /></template>);

      await focus(".d-combobox__trigger");
      await triggerKeyEvent(".d-combobox__trigger", "keydown", "Enter");

      assert
        .dom(".fk-d-menu-modal")
        .exists("the static select renders in a mobile modal");

      const options = findAll(".fk-d-menu-modal [role='option']");
      assert.strictEqual(
        document.activeElement,
        options[0],
        "real DOM focus moves to the first option inside the modal"
      );
      assert
        .dom(options[0])
        .hasAttribute(
          "tabindex",
          "0",
          "the focused option is the roving tab stop"
        );
      assert
        .dom(options[1])
        .hasAttribute(
          "tabindex",
          "-1",
          "the remaining options are not tab stops"
        );
      assert
        .dom(".d-combobox__trigger")
        .isNotFocused("focus is not stranded on the trigger outside the modal")
        .doesNotHaveAttribute(
          "aria-activedescendant",
          "focus mode does not use the out-of-modal trigger as a controller"
        );
    });
  }
);

module("Integration | ui-kit | select | menu modal decision", function (hooks) {
  setupRenderingTest(hooks);

  test("the menu service decision drives DMenu's mobile rendering", async function (assert) {
    const menu = getOwner(this).lookup("service:menu");

    assert.false(
      menu.shouldRenderInModal(true),
      "modalForMobile stays inline on desktop"
    );

    forceMobile();

    assert.true(
      menu.shouldRenderInModal(true),
      "modalForMobile selects the modal path on mobile"
    );

    await render(
      <template>
        <DMenu
          @identifier="modal-decision"
          @inline={{true}}
          @modalForMobile={{true}}
          @label="Open menu"
          @content="Menu content"
        />
      </template>
    );
    await click("[data-identifier='modal-decision']");

    assert
      .dom(".fk-d-menu-modal[data-identifier='modal-decision']")
      .hasText(
        "Menu content",
        "DMenu still follows the service decision and renders its modal"
      );
  });
});

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
      @placeholder="Pick some"
      @identifier="test-multi"
    >
      <:selection as |item|>{{item.name}}</:selection>
      <:item as |item|>{{item.name}}</:item>
    </DSelect>
  </template>
}

module(
  "Integration | ui-kit | select | DSelect (multi typeahead)",
  function (hooks) {
    setupRenderingTest(hooks);

    test("shows the placeholder when empty", async function (assert) {
      await render(<template><MultiHost /></template>);
      assert.dom(".d-combobox__input").hasAttribute("placeholder", "Pick some");
      assert.dom(".d-combobox__chip").doesNotExist();
    });

    test("selecting adds a chip, keeps the menu open, and keeps the picked row flagged", async function (assert) {
      await render(<template><MultiHost /></template>);
      await click(".d-combobox__input");
      assert.dom("[role='option']").exists({ count: 3 });

      await click("[role='option']");
      assert.dom("[role='listbox']").exists("multi stays open after a pick");
      assert
        .dom("[role='listbox']")
        .hasAttribute(
          "aria-multiselectable",
          "true",
          "a multi listbox declares multi-select semantics"
        );
      assert.dom(".d-combobox__chip").exists({ count: 1 }, "a chip is added");
      assert
        .dom("[role='option']")
        .exists({ count: 3 }, "the picked item stays in the list");
      assert
        .dom("[role='option'][aria-selected='true']")
        .exists({ count: 1 }, "the picked row is flagged selected");
      assert
        .dom(
          "[role='option'][aria-selected='true'] .d-combobox__option-selected-icon"
        )
        .exists("the selected row carries a check");

      // Clicking the first option again would toggle the now-selected item back
      // off, so pick a still-unselected row to add a second chip.
      await click("[role='option'][aria-selected='false']");
      assert.dom(".d-combobox__chip").exists({ count: 2 });
    });

    test("removing a chip deselects it", async function (assert) {
      await render(<template><MultiHost @value={{array 1 2}} /></template>);
      assert.dom(".d-combobox__chip").exists({ count: 2 });

      // The chip is a span; removal is its inner button, not the chip itself.
      await click(".d-combobox__chip .d-combobox__chip-remove");
      assert.dom(".d-combobox__chip").exists({ count: 1 }, "one chip removed");
    });

    test("each chip is a list item with an inner remove button named for its label", async function (assert) {
      await render(<template><MultiHost @value={{array 1}} /></template>);

      // The chips are a native labelled <ul>/<li> list (real "Selected items, list, N items"
      // semantics) rather than a role=group of spans; removal is the chip's inner button.
      assert
        .dom("li.d-combobox__chip")
        .exists({ count: 1 }, "the chip is a list item, not a button");
      assert
        .dom("ul.d-combobox__chip-list")
        .hasAttribute("aria-label", /.+/, "the chips are a labelled list");

      const removeButton = find(".d-combobox__chip .d-combobox__chip-remove");
      assert
        .dom(removeButton)
        .hasTagName("button", "removal is a dedicated inner button");

      const ids = removeButton.getAttribute("aria-labelledby").split(" ");
      assert.strictEqual(
        ids.length,
        2,
        "the button is named by two referenced nodes"
      );
      assert
        .dom(`#${ids[0]}`)
        .hasText(
          "Apple",
          "the first referenced node is the chip label (item-first)"
        );
      assert
        .dom(`#${ids[1]}`)
        .hasText(
          "Press Backspace or Delete to remove",
          "the second is the removal hint, so the name reads 'Apple, Press Backspace or Delete to remove'"
        );
    });

    test("a chip whose value contains a space still names its remove button", async function (assert) {
      const spacedItems = [{ id: "bug fix", name: "Bug fix" }];
      await render(
        <template>
          <DefaultHost
            @multiple={{true}}
            @items={{spacedItems}}
            @value={{array "bug fix"}}
          />
        </template>
      );

      const labelledby = find(".d-combobox__chip-remove").getAttribute(
        "aria-labelledby"
      );
      assert.strictEqual(
        labelledby.split(" ").length,
        2,
        "ids are minted from the index, so a spaced value does not tokenize the IDREF list"
      );
      labelledby.split(" ").forEach((id) => {
        assert
          .dom(`#${CSS.escape(id)}`)
          .exists(`the referenced node #${id} resolves`);
      });
    });

    test("uses default labels when presentation blocks are omitted", async function (assert) {
      await render(
        <template>
          <DefaultHost @multiple={{true}} @value={{array 1 2}} />
        </template>
      );

      assert
        .dom(".d-combobox__chip")
        .exists({ count: 2 }, "one fallback chip renders for each selection");
      assert
        .dom(".d-combobox__chip:first-child")
        .includesText("Apple", "chips use the selection fallback");

      await click(".d-combobox__input");
      assert
        .dom("[role='option']")
        .exists({ count: 3 }, "selected items stay in the list");
      assert
        .dom("[role='option'][aria-selected='true']")
        .exists({ count: 2 }, "the two selected rows are flagged");
      assert
        .dom("[role='option'][aria-selected='false']")
        .hasText("Cherry pie", "the unselected row uses the item fallback");
    });

    test("the selected-option icon is customizable via @selectedIcon", async function (assert) {
      await render(
        <template>
          <DSelect
            @items={{ITEMS}}
            @multiple={{true}}
            @value={{array 1}}
            @selectedIcon="star"
          />
        </template>
      );
      await click(".d-combobox__input");

      assert
        .dom(
          "[role='option'][aria-selected='true'] .d-combobox__option-selected-icon.d-icon-star"
        )
        .exists("the selected row uses the custom icon, not the default check");
    });
  }
);

module(
  "Integration | ui-kit | select | DSelect (@selectedIcon)",
  function (hooks) {
    setupRenderingTest(hooks);

    test("a single-select renders @selectedIcon on the selected option", async function (assert) {
      await render(
        <template>
          <DSelect @items={{ITEMS}} @value={{1}} @selectedIcon="star" />
        </template>
      );
      await click("[role='combobox']");

      assert
        .dom(
          "[role='option'][aria-selected='true'] .d-combobox__option-selected-icon.d-icon-star"
        )
        .exists("the selected row carries the custom icon in single-select");
    });

    test("a single-select without @selectedIcon renders no selected-option icon", async function (assert) {
      await render(
        <template><DSelect @items={{ITEMS}} @value={{1}} /></template>
      );
      await click("[role='combobox']");

      assert
        .dom(".d-combobox__option-selected-icon")
        .doesNotExist(
          "single-select shows no icon column unless @selectedIcon opts in"
        );
    });
  }
);

module(
  "Integration | ui-kit | select | DSelect (@showCaret)",
  function (hooks) {
    setupRenderingTest(hooks);

    test("the caret shows by default", async function (assert) {
      await render(<template><DSelect @items={{ITEMS}} /></template>);

      assert
        .dom(".d-combobox__caret")
        .exists("the trigger shows a caret without @showCaret");
    });

    test("@showCaret={{false}} suppresses the caret", async function (assert) {
      await render(
        <template><DSelect @items={{ITEMS}} @showCaret={{false}} /></template>
      );

      assert
        .dom(".d-combobox__caret")
        .doesNotExist("the caret is hidden when @showCaret is false");
    });
  }
);

module("Integration | ui-kit | select | DSelect (async)", function (hooks) {
  setupRenderingTest(hooks);

  test("synchronous resolvers supply the desktop typeahead label", async function (assert) {
    const resolveValue = (value) => ({ id: value, name: `Topic #${value}` });
    const resolveValues = (values) =>
      values.map((value) => ({ id: value, name: `Category #${value}` }));

    await render(
      <template>
        <DSelect
          class="sync-resolve-value"
          @items={{array}}
          @value={{123}}
          @resolveValue={{resolveValue}}
        />
        <DSelect
          class="sync-resolve-values"
          @items={{array}}
          @value={{456}}
          @resolveValues={{resolveValues}}
        />
      </template>
    );

    assert
      .dom(".sync-resolve-value [role='combobox']")
      .hasValue(
        "Topic #123",
        "the synchronously resolveValue label reaches the plain input"
      );
    assert
      .dom(".sync-resolve-values [role='combobox']")
      .hasValue(
        "Category #456",
        "the synchronously resolveValues label reaches the plain input"
      );
  });

  test("a synchronous resolver's label follows a later @value change", async function (assert) {
    const resolveValue = (value) => ({ id: value, name: `Topic #${value}` });

    class SyncHost extends Component {
      @tracked value = 1;

      @action
      bump() {
        this.value = 2;
      }

      <template>
        <DSelect
          @items={{array}}
          @value={{this.value}}
          @resolveValue={{resolveValue}}
        />
        <button
          type="button"
          class="bump"
          {{on "click" this.bump}}
        >bump</button>
      </template>
    }

    await render(<template><SyncHost /></template>);
    assert
      .dom("[role='combobox']")
      .hasValue("Topic #1", "the initial synchronous label renders");

    await click(".bump");
    assert
      .dom("[role='combobox']")
      .hasValue(
        "Topic #2",
        "a value change re-resolves rather than showing the stale label"
      );
  });

  test("an unresolvable single value shows the held value as unavailable, not a flash", async function (assert) {
    const resolveValue = () => Promise.reject(new Error("403"));

    await render(
      <template>
        <DSelect @items={{array}} @value={{7}} @resolveValue={{resolveValue}} />
      </template>
    );

    assert
      .dom("[role='combobox']")
      .hasValue(
        "7 (unavailable)",
        "the held value is shown as unavailable rather than blanking"
      );
    assert
      .dom(".d-combobox__trigger [role='alert']")
      .doesNotExist(
        "a rejected resolve does not flash an error inside the trigger"
      );
  });

  test("multi renders resolved chips plus an unavailable chip for an id that cannot resolve", async function (assert) {
    const resolveValues = (values) =>
      Promise.resolve(
        values.filter((v) => v === 1).map((v) => ({ id: v, name: "One" }))
      );

    await render(
      <template>
        <DSelect
          @items={{array}}
          @multiple={{true}}
          @value={{array 1 2}}
          @resolveValues={{resolveValues}}
        />
      </template>
    );

    assert
      .dom(".d-combobox__chip")
      .exists({ count: 2 }, "one chip per held id");
    assert
      .dom(".d-combobox__unresolved")
      .exists(
        { count: 1 },
        "the id that cannot resolve renders as unavailable"
      );
    assert
      .dom(".d-combobox__unresolved")
      .hasText(
        "2 Unavailable",
        "the unavailable chip shows the failed id, keeping ids distinct, and carries the state in text for screen readers"
      );
  });

  test("@selected seeds part of an async multi selection", async function (assert) {
    const resolvedValues = [];
    const selected = { id: 1, name: "One" };
    const resolveValues = (values) => {
      resolvedValues.push(...values);
      return Promise.resolve(
        values.map((value) => ({ id: value, name: "Two" }))
      );
    };

    await render(
      <template>
        <DSelect
          @items={{array}}
          @multiple={{true}}
          @value={{array 1 2}}
          @selected={{selected}}
          @resolveValues={{resolveValues}}
        />
      </template>
    );

    assert
      .dom(".d-combobox__chip")
      .exists({ count: 2 }, "both selected values render as chips");
    assert.deepEqual(
      resolvedValues,
      [2],
      "only the value missing from @selected is resolved"
    );
  });

  test("a custom createUnresolvedItem names the fallback on every surface", async function (assert) {
    const resolveValue = () => Promise.reject(new Error("404"));
    const createUnresolvedItem = (id) => ({ id, name: `Topic #${id}` });

    await render(
      <template>
        <DSelect
          @items={{array}}
          @value={{123}}
          @resolveValue={{resolveValue}}
          @createUnresolvedItem={{createUnresolvedItem}}
        />
      </template>
    );

    assert
      .dom("[role='combobox']")
      .hasValue(
        "Topic #123",
        "the named fallback reaches the plain input, with no generic suffix"
      );
  });

  test("a throwing createUnresolvedItem uses the default unavailable label", async function (assert) {
    const resolveValue = () => Promise.reject(new Error("404"));
    const createUnresolvedItem = () => {
      throw new Error("builder failed");
    };

    await render(
      <template>
        <DSelect
          @items={{array}}
          @value={{123}}
          @resolveValue={{resolveValue}}
          @createUnresolvedItem={{createUnresolvedItem}}
        />
      </template>
    );

    assert
      .dom("[role='combobox']")
      .hasValue(
        "123 (unavailable)",
        "the default fallback keeps the unavailable suffix when the builder throws"
      );
  });

  test("resolving a fallback label keeps the focused input mounted", async function (assert) {
    let resolveSelection;
    const selectionPromise = new Promise((resolve) => {
      resolveSelection = resolve;
    });
    const resolveValue = () => selectionPromise;

    const renderPromise = render(
      <template>
        <DSelect @items={{array}} @value={{2}} @resolveValue={{resolveValue}} />
      </template>
    );
    await waitFor("[role='combobox']");

    const input = find("[role='combobox']");
    input.focus();
    resolveSelection({ id: 2, name: "Banana" });
    await renderPromise;

    assert.strictEqual(
      find("[role='combobox']"),
      input,
      "the resolution updates the existing input"
    );
    assert.strictEqual(
      document.activeElement,
      input,
      "the input keeps focus while its label resolves"
    );
    assert
      .dom(input)
      .hasValue("Banana", "the resolved fallback becomes the input value");
    assert.strictEqual(
      input.selectionStart,
      input.selectionEnd,
      "a label arriving under an already-focused input is not auto-selected"
    );
  });

  test("an error can be retried without changing the query", async function (assert) {
    let requestCount = 0;
    let retryFilter;
    let resolveRetry;
    const retryPromise = new Promise((resolve) => {
      resolveRetry = resolve;
    });
    const load = (filter) => {
      requestCount++;

      if (requestCount === 1) {
        return Promise.reject(new Error("The first request failed"));
      }

      retryFilter = filter;
      return retryPromise;
    };

    await render(
      <template>
        <DSelect @load={{load}}>
          <:selection as |item|>{{item.name}}</:selection>
          <:item as |item|>{{item.name}}</:item>
        </DSelect>
      </template>
    );
    await fillIn("[role='combobox']", "ban");

    assert
      .dom(".d-combobox__error .d-icon-triangle-exclamation")
      .exists("the first request displays the muted async error state");
    assert
      .dom(".d-combobox__retry")
      .hasText("Retry", "the error offers a recovery action");

    const retryClick = click(".d-combobox__retry");
    await waitFor(".d-combobox__skeleton");
    assert
      .dom(".d-combobox__skeleton")
      .exists("retry transitions back through the loading state");
    resolveRetry(ITEMS.filter((item) => item.name === "Banana"));
    await retryClick;

    assert.dom(".d-combobox__error").doesNotExist("the error is cleared");
    assert.strictEqual(requestCount, 2, "retry makes one additional request");
    assert.strictEqual(retryFilter, "ban", "retry preserves the current query");
    assert
      .dom("[role='option']")
      .exists({ count: 1 }, "the successful retry displays its results")
      .hasText("Banana");
  });
});

module(
  "Integration | ui-kit | select | DSelect (modifySelectKit bridge)",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.afterEach(function () {
      clearCallbacks();
      resetLegacyBridge();
    });

    test("legacy prependContent rows render in the listbox", async function (assert) {
      withPluginApi((api) => {
        api
          .modifySelectKit("test-select")
          .prependContent(() => ({ id: 99, name: "Injected" }));
      });

      await render(<template><Host /></template>);
      await click("[role='combobox']");

      assert
        .dom("[role='option']")
        .exists({ count: 4 }, "the injected row joins the three client items");
      assert
        .dom("[role='listbox']")
        .includesText("Injected", "the legacy row is rendered");
    });

    test("a legacy action row runs its onSelect with the selectKit facade, without selecting", async function (assert) {
      let receivedValue = "unset";
      withPluginApi((api) => {
        api.modifySelectKit("test-select").prependContent(() => ({
          id: "act",
          name: "Act now",
          onSelect: (selectKit) => (receivedValue = selectKit.value),
        }));
      });

      await render(<template><Host /></template>);
      await click("[role='combobox']");
      // The action row is prepended, so it is the first option.
      await click("[role='option']");

      assert.strictEqual(
        receivedValue,
        null,
        "onSelect received the selectKit facade (reading its value works)"
      );
      assert
        .dom("[role='combobox']")
        .hasValue("", "the action row did not become the selection");
      assert
        .dom("[role='listbox']")
        .exists("an action row keeps the menu open");
    });
  }
);

// A controlled host that forwards the trigger-frame args (icon / caret / clear / lock).
class FrameHost extends Component {
  @tracked value = this.args.value ?? (this.args.multiple ? [] : null);

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @items={{ITEMS}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @multiple={{@multiple}}
      @variant={{@variant}}
      @clearable={{@clearable}}
      @icon={{@icon}}
      @caretIcon={{@caretIcon}}
      @disabled={{@disabled}}
      @readonly={{@readonly}}
      @identifier="test-select"
    >
      <:selection as |item|>{{item.name}}</:selection>
      <:item as |item|>{{item.name}}</:item>
    </DSelect>
  </template>
}

module(
  "Integration | ui-kit | select | DSelect (frame args)",
  function (hooks) {
    setupRenderingTest(hooks);

    test("@clearable shows a clear control only when there is a value, and clearing it does not open the menu", async function (assert) {
      await render(
        <template><FrameHost @clearable={{true}} @value={{1}} /></template>
      );

      assert
        .dom(".d-combobox__clear")
        .exists("the clear control shows while a value is selected")
        .hasAria(
          "label",
          "Clear selection",
          "single-select names it 'Clear selection'"
        );

      await click(".d-combobox__clear");

      assert
        .dom(".d-combobox__clear")
        .doesNotExist("clearing removes the value, so the control hides");
      assert
        .dom("[role='listbox']")
        .doesNotExist("the clear click does not bubble up to open the overlay");
    });

    test("@clearable is absent when nothing is selected", async function (assert) {
      await render(<template><FrameHost @clearable={{true}} /></template>);

      assert
        .dom(".d-combobox__clear")
        .doesNotExist("no clear control while the selection is empty");
    });

    test("@clearable stays out of the tab order and restores trigger focus after pointer clearing", async function (assert) {
      await render(
        <template>
          <FrameHost @variant="static" @clearable={{true}} @value={{1}} />
        </template>
      );

      assert
        .dom(".d-combobox__clear")
        .hasAttribute(
          "tabindex",
          "-1",
          "the pointer affordance is not a tab stop"
        );

      await click(".d-combobox__clear");

      assert
        .dom(".d-combobox__trigger")
        .isFocused("focus returns to the static combobox controller");
    });

    test("@clearable on multi clears every chip and names itself 'Clear all'", async function (assert) {
      await render(
        <template>
          <FrameHost
            @multiple={{true}}
            @clearable={{true}}
            @value={{array 1 2}}
          />
        </template>
      );

      assert
        .dom(".d-combobox__chip")
        .exists({ count: 2 }, "two chips to start");
      assert
        .dom(".d-combobox__clear")
        .hasAria("label", "Clear all", "multi-select names it 'Clear all'");

      await click(".d-combobox__clear");

      assert
        .dom(".d-combobox__chip")
        .doesNotExist("clearing removes every chip");
    });

    test("@clearable clears a static control from the keyboard (Delete)", async function (assert) {
      await render(
        <template>
          <FrameHost @variant="static" @clearable={{true}} @value={{1}} />
        </template>
      );

      const trigger = find("[role='combobox']");
      await focus(trigger);
      await triggerKeyEvent(trigger, "keydown", "Delete");

      assert
        .dom(".d-combobox__value")
        .doesNotExist("Delete on the closed control empties the selection");
      assert
        .dom("[role='listbox']")
        .doesNotExist("the keyboard clear does not open the overlay");
    });

    test("@clearable clears a single typeahead from the keyboard once the query is empty", async function (assert) {
      await render(
        <template><FrameHost @clearable={{true}} @value={{1}} /></template>
      );

      const input = find("[role='combobox']");
      await fillIn(input, "");
      await triggerKeyEvent(input, "keydown", "Backspace");

      assert
        .dom("[role='combobox']")
        .hasValue(
          "",
          "Backspace on the empty query clears the single selection"
        );
    });

    test("@icon renders a leading decorative icon", async function (assert) {
      await render(
        <template>
          <FrameHost @variant="static" @icon="tag" @value={{1}} />
        </template>
      );

      assert
        .dom(".d-combobox__leading-icon")
        .exists("the leading icon renders")
        .hasClass("d-icon-tag", "it is the requested glyph");
    });

    test("@caretIcon hash swaps the caret between the open and closed glyphs", async function (assert) {
      await render(
        <template>
          <FrameHost
            @variant="static"
            @caretIcon={{hash open="chevron-up" closed="chevron-down"}}
            @value={{1}}
          />
        </template>
      );

      assert
        .dom(".d-combobox__caret")
        .hasClass("d-icon-chevron-down", "closed shows the closed glyph");

      await click("[role='combobox']");

      assert
        .dom(".d-combobox__caret")
        .hasClass("d-icon-chevron-up", "open swaps to the open glyph");
    });

    test("@caretIcon string uses one glyph in both states", async function (assert) {
      await render(
        <template>
          <FrameHost @variant="static" @caretIcon="caret-down" @value={{1}} />
        </template>
      );

      assert.dom(".d-combobox__caret").hasClass("d-icon-caret-down");

      await click("[role='combobox']");

      assert
        .dom(".d-combobox__caret")
        .hasClass("d-icon-caret-down", "the same glyph stays while open");
    });

    test("@caretIcon with only an open glyph falls back to the default closed glyph", async function (assert) {
      await render(
        <template>
          <FrameHost
            @variant="static"
            @caretIcon={{hash open="chevron-up"}}
            @value={{1}}
          />
        </template>
      );

      assert
        .dom(".d-combobox__caret")
        .hasClass(
          "d-icon-angle-down",
          "the missing closed side uses the default"
        );

      await click("[role='combobox']");

      assert
        .dom(".d-combobox__caret")
        .hasClass("d-icon-chevron-up", "the supplied open side is preserved");
    });

    test("@caretIcon with only a closed glyph falls back to the default open glyph", async function (assert) {
      await render(
        <template>
          <FrameHost
            @variant="static"
            @caretIcon={{hash closed="chevron-down"}}
            @value={{1}}
          />
        </template>
      );

      assert
        .dom(".d-combobox__caret")
        .hasClass(
          "d-icon-chevron-down",
          "the supplied closed side is preserved"
        );

      await click("[role='combobox']");

      assert
        .dom(".d-combobox__caret")
        .hasClass("d-icon-angle-up", "the missing open side uses the default");
    });

    test("the caret remains the last trigger child when a clear control is present", async function (assert) {
      await render(
        <template>
          <FrameHost @clearable={{true}} @value={{1}} />
          <FrameHost @variant="button" @clearable={{true}} @value={{1}} />
          <FrameHost @variant="static" @clearable={{true}} @value={{1}} />
          <FrameHost
            @multiple={{true}}
            @clearable={{true}}
            @value={{array 1 2}}
          />
        </template>
      );

      for (const trigger of findAll(".d-combobox__trigger")) {
        assert.true(
          trigger.lastElementChild?.classList.contains("d-combobox__caret"),
          "the caret is the trigger's last element child"
        );
        assert.true(
          trigger.lastElementChild?.previousElementSibling?.classList.contains(
            "d-combobox__clear"
          ),
          "the clear button immediately precedes the caret"
        );
      }
    });

    test("@disabled makes the control inert: not focusable, cannot open, no clear", async function (assert) {
      await render(
        <template>
          <FrameHost
            @variant="static"
            @disabled={{true}}
            @clearable={{true}}
            @value={{1}}
          />
        </template>
      );

      assert
        .dom("[role='combobox']")
        .hasAria("disabled", "true", "the control is marked aria-disabled")
        .doesNotHaveAttribute("tabindex", "and dropped from the tab order");
      assert
        .dom(".d-combobox__clear")
        .doesNotExist("a disabled control offers no clear affordance");

      await click("[role='combobox']");
      assert
        .dom("[role='listbox']")
        .doesNotExist("a disabled control does not open");
    });

    test("@disabled sets the native attribute on the typeahead input", async function (assert) {
      await render(
        <template><FrameHost @disabled={{true}} @value={{1}} /></template>
      );

      assert
        .dom("[role='combobox']")
        .isDisabled("the input carries native disabled");
    });

    test("@disabled makes multi chip removal inert and blocks pointer opening", async function (assert) {
      await render(
        <template>
          <FrameHost
            @multiple={{true}}
            @disabled={{true}}
            @value={{array 1 2}}
          />
        </template>
      );

      const removeButton = find(".d-combobox__chip-remove");
      assert
        .dom(removeButton)
        .isDisabled("the chip remove control is natively disabled");

      await click(".d-combobox__trigger");

      assert
        .dom(".d-combobox__chip")
        .exists({ count: 2 }, "the disabled selection remains unchanged");
      assert
        .dom("[role='listbox']")
        .doesNotExist("the locked multi select stays closed");
    });

    test("@readonly stays focusable but cannot open or edit", async function (assert) {
      await render(
        <template>
          <FrameHost @variant="static" @readonly={{true}} @value={{1}} />
        </template>
      );

      assert
        .dom("[role='combobox']")
        .hasAria("readonly", "true", "the control is marked aria-readonly")
        .hasAttribute("tabindex", "0", "yet stays in the tab order");

      await click("[role='combobox']");
      assert
        .dom("[role='listbox']")
        .doesNotExist("a readonly control does not open");
    });

    test("@readonly sets the native attribute on the typeahead input", async function (assert) {
      await render(
        <template><FrameHost @readonly={{true}} @value={{1}} /></template>
      );

      assert
        .dom("[role='combobox']")
        .hasAttribute("readonly", "", "the input carries native readonly")
        .isNotDisabled("readonly is not disabled");
    });

    test("@readonly typeahead preserves its selected value and ignores keyboard open or typing", async function (assert) {
      await render(
        <template><FrameHost @readonly={{true}} @value={{1}} /></template>
      );

      const input = find("[role='combobox']");
      assert
        .dom(".d-combobox__presentation")
        .hasText("Apple", "the selected value remains readable");

      await focus(input);
      assert.dom(input).isFocused("the readonly input can receive focus");

      await triggerKeyEvent(input, "keydown", "ArrowDown");
      await triggerKeyEvent(input, "keydown", "X");

      assert
        .dom("[role='listbox']")
        .doesNotExist("ArrowDown does not open the readonly select");
      assert
        .dom(".d-combobox__presentation")
        .hasText("Apple", "typing does not replace the selected presentation");
    });

    test("@readonly blocks ArrowLeft navigation into multi chips", async function (assert) {
      await render(
        <template>
          <FrameHost
            @multiple={{true}}
            @readonly={{true}}
            @value={{array 1 2}}
          />
        </template>
      );

      const input = find("[role='combobox']");
      await focus(input);
      await triggerKeyEvent(input, "keydown", "ArrowLeft");

      assert
        .dom(input)
        .isFocused("ArrowLeft cannot move focus into disabled chip controls");

      assert
        .dom("[role='listbox']")
        .doesNotExist("chip navigation does not open the locked menu");
      assert
        .dom(".d-combobox__chip")
        .exists({ count: 2 }, "the locked selection remains unchanged");
    });

    test("a lock toggled off after mount restores pointer opening", async function (assert) {
      class ToggleHost extends Component {
        @tracked locked = true;

        @action
        unlock() {
          this.locked = false;
        }

        <template>
          <button type="button" class="unlock" {{on "click" this.unlock}}>
            unlock
          </button>
          <DSelect
            @items={{ITEMS}}
            @value={{1}}
            @variant="static"
            @disabled={{this.locked}}
            @identifier="test-select"
          >
            <:selection as |item|>{{item.name}}</:selection>
            <:item as |item|>{{item.name}}</:item>
          </DSelect>
        </template>
      }

      await render(<template><ToggleHost /></template>);

      await click("[role='combobox']");
      assert
        .dom("[role='listbox']")
        .doesNotExist("locked at mount, a pointer click does not open");

      await click(".unlock");
      await click("[role='combobox']");
      assert
        .dom("[role='listbox']")
        .exists(
          "once the lock clears, pointer opening works even though DMenu wired its listeners at mount"
        );
    });
  }
);

module(
  "Integration | ui-kit | select | DSelect (input throttle)",
  function (hooks) {
    setupRenderingTest(hooks);

    test("a query below @minChars shows a keep-typing hint and renders no list, skeleton, or source call", async function (assert) {
      let loadCalls = 0;
      const load = (filter) => {
        loadCalls++;
        return ITEMS.filter((item) =>
          item.name.toLowerCase().includes(filter.toLowerCase())
        );
      };

      await render(
        <template>
          <DSelect
            @load={{load}}
            @minChars={{3}}
            @identifier="test-select"
            @placeholder="Search"
          />
        </template>
      );

      await fillIn("[role='combobox']", "ap");

      assert
        .dom(".d-combobox__min-chars")
        .exists("a short query shows the keep-typing hint")
        .hasText(
          "Keep typing 1 more character…",
          "the hint counts the remaining characters"
        );
      assert
        .dom("[role='listbox']")
        .doesNotExist("no list renders below the threshold");
      assert
        .dom(".d-combobox__skeleton")
        .doesNotExist("no loading skeleton flashes below the threshold");
      assert.strictEqual(
        loadCalls,
        0,
        "the source is never called below the threshold"
      );
    });

    test("reaching @minChars renders the list and calls the source", async function (assert) {
      let loadCalls = 0;
      const load = (filter) => {
        loadCalls++;
        return ITEMS.filter((item) =>
          item.name.toLowerCase().includes(filter.toLowerCase())
        );
      };

      await render(
        <template>
          <DSelect
            @load={{load}}
            @minChars={{3}}
            @identifier="test-select"
            @placeholder="Search"
          />
        </template>
      );

      await fillIn("[role='combobox']", "app");
      await waitFor("[role='listbox']");

      assert
        .dom(".d-combobox__min-chars")
        .doesNotExist("at the threshold the hint is gone");
      assert
        .dom("[role='listbox']")
        .exists("the list renders once the query is long enough");
      assert.true(
        loadCalls > 0,
        "the source is called at or above the threshold"
      );
    });

    test("dropping back below @minChars restores the keep-typing hint", async function (assert) {
      const load = () => ITEMS;

      await render(
        <template>
          <DSelect
            @load={{load}}
            @minChars={{3}}
            @identifier="test-select"
            @placeholder="Search"
          />
        </template>
      );

      await fillIn("[role='combobox']", "app");
      await waitFor("[role='listbox']");
      assert.dom("[role='listbox']").exists("a long enough query lists");

      await fillIn("[role='combobox']", "ap");
      assert
        .dom("[role='listbox']")
        .doesNotExist("shrinking below the threshold hides the list");
      assert
        .dom(".d-combobox__min-chars")
        .exists("and restores the keep-typing hint");
    });

    test("@minChars defaults to 0, searching on any input", async function (assert) {
      const load = () => ITEMS;

      await render(
        <template>
          <DSelect
            @load={{load}}
            @identifier="test-select"
            @placeholder="Search"
          />
        </template>
      );

      await fillIn("[role='combobox']", "a");
      await waitFor("[role='listbox']");

      assert
        .dom(".d-combobox__min-chars")
        .doesNotExist("no threshold means no hint");
      assert
        .dom("[role='listbox']")
        .exists("a single character already searches");
    });

    test("a client source renders instantly with no skeleton (debounce defaults off)", async function (assert) {
      await render(
        <template>
          <DSelect
            @items={{ITEMS}}
            @variant="button"
            @identifier="test-select"
          />
        </template>
      );

      await click(".d-combobox__trigger");

      assert
        .dom("[role='listbox']")
        .exists("the client list renders immediately");
      assert
        .dom(".d-combobox__skeleton")
        .doesNotExist("a synchronous source flashes no loading skeleton");
    });

    test("an empty query is below @minChars: the hint shows and the source is not called", async function (assert) {
      const filters = [];
      const load = (filter) => {
        filters.push(filter);
        return ITEMS;
      };

      await render(
        <template>
          <DSelect @load={{load}} @minChars={{3}} @identifier="test-select" />
        </template>
      );

      await click("[role='combobox']");

      assert
        .dom(".d-combobox__min-chars")
        .exists(
          "an empty query is below the minimum, so the hint shows on open"
        )
        .hasText(
          "Keep typing 3 more characters…",
          "the hint counts from the full minimum"
        );
      assert
        .dom("[role='listbox']")
        .doesNotExist("no list flashes on open below the minimum");
      assert.strictEqual(
        filters.length,
        0,
        "the source is not called for a below-minimum empty query"
      );
    });

    test("a chosen typeahead value hides the input placeholder", async function (assert) {
      await render(
        <template>
          <DSelect
            @items={{ITEMS}}
            @value={{1}}
            @placeholder="Choose an option"
            @identifier="test-select"
          >
            <:selection as |item|>{{item.name}}</:selection>
            <:item as |item|>{{item.name}}</:item>
          </DSelect>
        </template>
      );

      assert
        .dom(".d-combobox__presentation")
        .hasText("Apple", "the selection presentation shows the chosen value");
      assert.strictEqual(
        find("[role='combobox']").placeholder,
        "",
        "the input shows no placeholder next to an already-chosen value"
      );
    });

    test("@debounce={{false}} keeps a function source synchronous", async function (assert) {
      const filters = [];
      const load = (filter) => {
        filters.push(filter);
        return ITEMS.filter((item) =>
          item.name.toLowerCase().includes(filter.toLowerCase())
        );
      };

      await render(
        <template>
          <DSelect
            @load={{load}}
            @debounce={{false}}
            @variant="button"
            @identifier="test-select"
          />
        </template>
      );

      await click(".d-combobox__trigger");
      await fillIn(".d-combobox__filter", "ban");

      assert
        .dom(".d-combobox__skeleton")
        .doesNotExist("an explicit false never enters a loading state");
      assert
        .dom("[role='option']")
        .exists({ count: 1 }, "the re-filtered result renders")
        .hasText("Banana", "the latest synchronous result is shown");
      assert.strictEqual(
        filters.at(-1),
        "ban",
        "false is preserved instead of falling back to the async-source default"
      );
    });

    test("a create-enabled select offers no create row below @minChars", async function (assert) {
      const createItem = (filter) => ({
        id: filter,
        name: `Create ${filter}`,
        __create: true,
      });

      await render(
        <template>
          <DSelect
            @items={{ITEMS}}
            @minChars={{3}}
            @allowCreate={{true}}
            @createItem={{createItem}}
            @identifier="test-select"
          />
        </template>
      );

      await fillIn("[role='combobox']", "xy");

      assert
        .dom("[role='option'].--create")
        .doesNotExist("the synthetic create item is not built below threshold");
      assert
        .dom(".d-combobox__min-chars")
        .hasText(
          "Keep typing 1 more character…",
          "the threshold hint replaces all list items"
        );
    });

    test("a create-enabled select offers a create row when the source has no matches", async function (assert) {
      const createItem = (filter) => ({
        id: filter,
        name: `Create ${filter}`,
        __create: true,
      });

      await render(
        <template>
          <DSelect
            @items={{ITEMS}}
            @allowCreate={{true}}
            @createItem={{createItem}}
            @identifier="test-select"
          />
        </template>
      );

      await fillIn("[role='combobox']", "dragonfruit");

      assert
        .dom("[role='option'].--create")
        .exists("the synthetic create row replaces the raw empty state")
        .hasText("Create dragonfruit", "the row uses the proposed value");
      assert
        .dom(".d-combobox__empty")
        .doesNotExist("the final list is not treated as empty");
    });

    test("mobile typeahead renders the @minChars hint inside its modal", async function (assert) {
      forceMobile();

      await render(
        <template>
          <DSelect @items={{ITEMS}} @minChars={{3}} @identifier="test-select" />
        </template>
      );

      await click(".d-combobox__trigger");
      await fillIn(".fk-d-menu-modal [role='combobox']", "ap");

      assert
        .dom(".fk-d-menu-modal .d-combobox__min-chars[role='status']")
        .hasText(
          "Keep typing 1 more character…",
          "the mobile modal contains the visible status hint"
        );
      assert
        .dom(".fk-d-menu-modal [role='listbox']")
        .doesNotExist("the modal list is gated below threshold");
    });

    test("the same remaining @minChars count is not announced twice", async function (assert) {
      const announce = sinon.spy(
        getOwner(this).lookup("service:a11y"),
        "announce"
      );

      await render(
        <template>
          <DSelect @items={{ITEMS}} @minChars={{3}} @identifier="test-select" />
        </template>
      );

      await fillIn("[role='combobox']", "a");
      await fillIn("[role='combobox']", "b");

      assert.strictEqual(
        announce.withArgs("Keep typing 2 more characters…", "polite").callCount,
        1,
        "changing the query without changing the remaining count stays silent"
      );
    });

    test("below @minChars the combobox advertises no listbox reference", async function (assert) {
      await render(
        <template>
          <DSelect @items={{ITEMS}} @minChars={{3}} @identifier="test-select" />
        </template>
      );

      await fillIn("[role='combobox']", "ap");

      assert
        .dom(".d-combobox__min-chars")
        .exists("the keep-typing hint is shown below threshold");
      assert
        .dom("[role='combobox']")
        .doesNotHaveAttribute(
          "aria-controls",
          "no dangling aria-controls while no listbox is rendered"
        )
        .doesNotHaveAttribute(
          "aria-owns",
          "no dangling aria-owns while no listbox is rendered"
        );
    });

    test("the button panel filter advertises no listbox below @minChars", async function (assert) {
      await render(
        <template>
          <DSelect
            @items={{ITEMS}}
            @minChars={{3}}
            @variant="button"
            @identifier="test-select"
          />
        </template>
      );

      await click(".d-combobox__trigger");
      await fillIn(".d-combobox__filter", "ap");

      assert
        .dom(".d-combobox__filter")
        .doesNotHaveAttribute(
          "aria-controls",
          "the panel filter drops its listbox reference below threshold"
        );
    });

    test("@debounce={{true}} on a client source renders without crashing", async function (assert) {
      await render(
        <template>
          <DSelect
            @items={{ITEMS}}
            @debounce={{true}}
            @variant="button"
            @identifier="test-select"
          />
        </template>
      );

      await click(".d-combobox__trigger");
      await fillIn(".d-combobox__filter", "ban");
      await waitFor("[role='option']");

      assert
        .dom("[role='option']")
        .exists(
          { count: 1 },
          "a forced-debounce synchronous source resolves through the promise path"
        )
        .hasText("Banana", "and shows the filtered result");
    });

    test("re-entering below @minChars announces the hint again", async function (assert) {
      const announce = sinon.spy(
        getOwner(this).lookup("service:a11y"),
        "announce"
      );

      await render(
        <template>
          <DSelect @items={{ITEMS}} @minChars={{3}} @identifier="test-select" />
        </template>
      );

      await fillIn("[role='combobox']", "a");
      await fillIn("[role='combobox']", "app");
      await fillIn("[role='combobox']", "a");

      assert.strictEqual(
        announce.withArgs("Keep typing 2 more characters…", "polite").callCount,
        2,
        "leaving and re-entering the below-threshold state re-announces the hint"
      );
    });
  }
);

module(
  "Integration | ui-kit | select | DSelect (passthrough + empty block)",
  function (hooks) {
    setupRenderingTest(hooks);

    test("@onShow and @onClose compose with the internal open/close handling", async function (assert) {
      let shown = 0;
      let closed = 0;
      const onShow = () => shown++;
      const onClose = () => closed++;

      await render(
        <template>
          <DSelect
            @items={{ITEMS}}
            @onShow={{onShow}}
            @onClose={{onClose}}
            @identifier="test-select"
          />
        </template>
      );

      await click("[role='combobox']");
      assert.strictEqual(shown, 1, "the consumer @onShow fires on open");

      await fillIn("[role='combobox']", "ban");
      await triggerKeyEvent("[role='combobox']", "keydown", "Escape");
      assert.strictEqual(closed, 1, "the consumer @onClose fires on close");

      // The internal typeahead reset must survive composition: reopening starts from a cleared
      // query, so the full list is back rather than the previous "ban" filter.
      await click("[role='combobox']");
      assert
        .dom("[role='option']")
        .exists(
          { count: ITEMS.length },
          "the internal query reset still runs alongside the consumer @onClose"
        );
    });

    test("a consumer :empty block replaces the default text but keeps the status live-region", async function (assert) {
      await render(
        <template>
          <DSelect @items={{ITEMS}} @identifier="test-select">
            <:empty><span class="custom-empty">No luck</span></:empty>
          </DSelect>
        </template>
      );

      await fillIn("[role='combobox']", "zzzz");

      assert
        .dom(".custom-empty")
        .exists("the consumer empty block renders for no matches");
      assert
        .dom("[role='status'] .custom-empty")
        .exists("the custom empty content stays inside a live-region status");
      assert
        .dom(".d-combobox__empty")
        .doesNotContainText(
          "No results found",
          "the default no-results text is replaced by the consumer content"
        );
    });

    test("@onShow fires once per open even if the open trigger is clicked again", async function (assert) {
      let shown = 0;
      const onShow = () => shown++;

      await render(
        <template>
          <DSelect
            @items={{ITEMS}}
            @onShow={{onShow}}
            @identifier="test-select"
          />
        </template>
      );

      await click("[role='combobox']");
      await click("[role='combobox']");

      assert.strictEqual(
        shown,
        1,
        "clicking the already-open trigger does not re-fire @onShow"
      );
    });

    test("without an :empty block the default no-results still shows", async function (assert) {
      await render(
        <template>
          <DSelect @items={{ITEMS}} @identifier="test-select" />
        </template>
      );

      await fillIn("[role='combobox']", "zzzz");

      assert
        .dom(".d-combobox__empty")
        .exists("the built-in no-results status remains the default");
    });

    test("@placement forwards to the overlay positioning", async function (assert) {
      await render(
        <template>
          <DSelect
            @items={{ITEMS}}
            @placement="bottom-end"
            @identifier="test-select"
          />
        </template>
      );

      await click("[role='combobox']");

      assert
        .dom("[data-placement]")
        .hasAttribute(
          "data-placement",
          "bottom-end",
          "the custom placement reaches floating-ui (default would be bottom-start)"
        );
    });

    test("@offset forwards to the overlay positioning", async function (assert) {
      // A large offset pushes the overlay well clear of the trigger; the exact pixel gap is
      // clamped by floating-ui's viewport math in the tiny test fixture, so this asserts the
      // offset visibly increases the spacing rather than a brittle exact value. The default
      // gap (offset 10) is only a few pixels.
      await render(
        <template>
          <DSelect @items={{ITEMS}} @offset={{200}} @identifier="test-select" />
        </template>
      );

      await click("[role='combobox']");

      assert
        .dom("[data-placement]")
        .hasAttribute(
          "data-placement",
          "bottom-start",
          "the overlay stays below the trigger, so the gap reflects the offset"
        );
      const trigger = find(".d-combobox__trigger").getBoundingClientRect();
      const content = find("[data-placement]").getBoundingClientRect();
      assert.true(
        content.top - trigger.bottom > 40,
        "the custom offset pushes the overlay well below the trigger (default gap is a few px)"
      );
    });

    test("an @onShow that mutates state does not disturb the open (deferred past positioning)", async function (assert) {
      class ReproHost extends Component {
        @tracked count = 0;
        @tracked value = null;

        @action
        onShow() {
          this.count++;
        }

        @action
        onChange(v) {
          this.value = v;
        }

        <template>
          <DSelect
            @items={{ITEMS}}
            @value={{this.value}}
            @onChange={{this.onChange}}
            @onShow={{this.onShow}}
            @identifier="test-select"
          />
          <p class="repro-count">{{this.count}}</p>
        </template>
      }

      await render(<template><ReproHost /></template>);
      await click("[role='combobox']");

      assert
        .dom(".repro-count")
        .hasText("1", "the consumer @onShow still runs (once, after settling)");
      assert.strictEqual(
        document.activeElement,
        find("[role='combobox']"),
        "the query input keeps focus through the open"
      );
      assert
        .dom("[role='listbox']")
        .exists("the overlay is open and its listbox rendered");
    });

    test("@onShow and @onClose fire once for button and static variants", async function (assert) {
      const buttonOnShow = sinon.spy();
      const buttonOnClose = sinon.spy();
      const staticOnShow = sinon.spy();
      const staticOnClose = sinon.spy();

      await render(
        <template>
          <DSelect
            class="callback-button"
            @items={{ITEMS}}
            @variant="button"
            @onShow={{buttonOnShow}}
            @onClose={{buttonOnClose}}
          />
          <DSelect
            class="callback-static"
            @items={{ITEMS}}
            @variant="static"
            @onShow={{staticOnShow}}
            @onClose={{staticOnClose}}
          />
        </template>
      );

      await click(".callback-button");
      assert.true(buttonOnShow.calledOnce, "button reports one open");
      await triggerKeyEvent(".d-combobox__filter", "keydown", "Escape");
      assert.true(buttonOnClose.calledOnce, "button reports one close");

      await click(".callback-static");
      assert.true(staticOnShow.calledOnce, "static reports one open");
      await triggerKeyEvent(".callback-static", "keydown", "Escape");
      assert.true(staticOnClose.calledOnce, "static reports one close");
    });

    test("an async source resolving to an empty array renders the consumer :empty block", async function (assert) {
      const load = () => Promise.resolve([]);

      await render(
        <template>
          <DSelect
            @load={{load}}
            @debounce={{false}}
            @variant="button"
            @identifier="test-select"
          >
            <:empty><span class="async-empty">No remote matches</span></:empty>
          </DSelect>
        </template>
      );

      await click(".d-combobox__trigger");
      await waitFor(".async-empty");

      assert
        .dom(".async-empty")
        .hasText(
          "No remote matches",
          "the resolved empty response reaches the named block"
        );
    });

    test("the consumer :empty block stays hidden while results are available", async function (assert) {
      await render(
        <template>
          <DSelect @items={{ITEMS}} @variant="button">
            <:empty><span class="unexpected-empty">No matches</span></:empty>
          </DSelect>
        </template>
      );

      await click(".d-combobox__trigger");

      assert
        .dom("[role='option']")
        .exists({ count: ITEMS.length }, "available results render normally");
      assert
        .dom(".unexpected-empty")
        .doesNotExist("the empty block is not rendered alongside results");
    });

    test("@placement and @offset preserve the mobile modal path", async function (assert) {
      forceMobile();

      await render(
        <template>
          <DSelect
            @items={{ITEMS}}
            @placement="top-end"
            @offset={{200}}
            @variant="button"
          />
        </template>
      );

      await click(".d-combobox__trigger");

      assert
        .dom(".fk-d-menu-modal")
        .exists("the select still opens in a modal");
      assert
        .dom(".fk-d-menu-modal [role='option']")
        .exists({ count: ITEMS.length }, "the modal still renders the list");
      assert
        .dom("[data-placement]")
        .doesNotExist("the modal does not enter the floating-position path");
    });
  }
);

module(
  "Integration | ui-kit | select | DSelect (overlay scroll)",
  function (hooks) {
    setupRenderingTest(hooks);

    test("auto-highlighting the first option on open does not call scrollIntoView", async function (assert) {
      // The overlay is portalled and positioned by floating-ui asynchronously. A synchronous
      // `@items` source renders the options immediately, before that positioning, so the
      // first option is still at the portal root (top of page). `scrollIntoView` on it would
      // scroll the whole page there; the roving highlight must scroll within the listbox only.
      const spy = sinon.spy(HTMLElement.prototype, "scrollIntoView");

      await render(
        <template>
          <DSelect @items={{ITEMS}} @identifier="test-select" />
        </template>
      );
      spy.resetHistory();

      await click("[role='combobox']");

      assert
        .dom("[role='option'].--active")
        .exists("the first option is auto-highlighted on open");
      assert.false(
        spy.called,
        "the highlight is scrolled within the listbox, not via scrollIntoView (which scrolls the portalled overlay's page position)"
      );
    });

    test("opening with a value activates the selected option and scrolls to it", async function (assert) {
      const many = Array.from({ length: 40 }, (_, i) => ({
        id: i + 1,
        name: `Item ${i + 1}`,
      }));
      const spy = sinon.spy(HTMLElement.prototype, "scrollIntoView");

      await render(
        <template>
          <DSelect @items={{many}} @value={{30}} @identifier="test-select" />
        </template>
      );
      spy.resetHistory();

      await click("[role='combobox']");

      assert
        .dom("[role='option'].--active")
        .hasText(
          "Item 30",
          "the cursor is restored to the user's choice, not the first row"
        );
      assert.true(
        find(".d-virtual-list").scrollTop > 0,
        "and the list viewport is scrolled to it"
      );
      assert.false(
        spy.called,
        "scrolled within the list viewport, never via scrollIntoView"
      );
    });

    test("opening with a value while filtering activates the first match, not the selection", async function (assert) {
      const many = Array.from({ length: 40 }, (_, i) => ({
        id: i + 1,
        name: `Item ${i + 1}`,
      }));

      await render(
        <template>
          <DSelect @items={{many}} @value={{30}} @identifier="test-select" />
        </template>
      );

      await click("[role='combobox']");
      await fillIn("[role='combobox']", "Item 1");

      assert
        .dom("[role='option'].--active")
        .hasText(
          "Item 1",
          "Enter should take the best match for what was typed"
        );
    });

    test("keyboard navigation scrolls an off-screen option into view within the listbox", async function (assert) {
      const many = Array.from({ length: 40 }, (_, i) => ({
        id: i + 1,
        name: `Item ${i + 1}`,
      }));

      await render(
        <template>
          <DSelect @items={{many}} @identifier="test-select" />
        </template>
      );

      await click("[role='combobox']");
      // The scroll viewport is the DVirtualList wrapper around the listbox; the listbox ul
      // itself is the (non-scrolling) sizer.
      const viewport = find(".d-virtual-list");
      assert.strictEqual(
        viewport.scrollTop,
        0,
        "the list starts at the top with the first option highlighted"
      );

      for (let i = 0; i < 20; i++) {
        await triggerKeyEvent("[role='combobox']", "keydown", "ArrowDown");
      }

      assert.true(
        viewport.scrollTop > 0,
        "arrowing down scrolls the active option into view inside the list viewport"
      );
    });
  }
);

module(
  "Integration | ui-kit | select | DSelect (review fixes)",
  function (hooks) {
    setupRenderingTest(hooks);

    test("reopening a select clears a previous roving highlight", async function (assert) {
      // A button select does not auto-highlight on open, so the roving highlight is only ever
      // seeded by navigation. The highlight is rendered from tracked state (`activeOptionKey`);
      // if it were not cleared on close, a reopened list would render a stale `--active` with
      // no matching aria-activedescendant.
      await render(
        <template><DSelect @items={{ITEMS}} @variant="button" /></template>
      );

      await click(".d-combobox__trigger");
      assert
        .dom("[role='option'].--active")
        .doesNotExist("a button select opens with no highlight");

      await triggerKeyEvent("[role='combobox']", "keydown", "ArrowDown");
      assert
        .dom("[role='option'].--active")
        .exists("arrowing down seeds the highlight");

      await triggerKeyEvent("[role='combobox']", "keydown", "Escape");
      await click(".d-combobox__trigger");
      assert
        .dom("[role='option'].--active")
        .doesNotExist("reopening does not restore the stale highlight");
    });

    test("the static and button control roots carry the accessible name from @label", async function (assert) {
      await render(
        <template>
          <DSelect
            class="lbl-static"
            @items={{ITEMS}}
            @value={{1}}
            @variant="static"
            @label="Category"
          >
            <:selection as |item|>{{item.name}}</:selection>
            <:item as |item|>{{item.name}}</:item>
          </DSelect>
          <DSelect
            class="lbl-button"
            @items={{ITEMS}}
            @value={{1}}
            @variant="button"
            @label="Category"
          >
            <:selection as |item|>{{item.name}}</:selection>
            <:item as |item|>{{item.name}}</:item>
          </DSelect>
        </template>
      );

      assert
        .dom(".lbl-static[role='combobox']")
        .hasAria("label", "Category", "the static combobox root is named");
      assert
        .dom(".lbl-button[role='button']")
        .hasAria("label", "Category", "the button disclosure root is named");
    });

    test("a readonly button variant is announced aria-disabled (buttons have no readonly)", async function (assert) {
      await render(
        <template>
          <DSelect
            class="ro-btn"
            @items={{ITEMS}}
            @value={{1}}
            @variant="button"
            @readonly={{true}}
          >
            <:selection as |item|>{{item.name}}</:selection>
            <:item as |item|>{{item.name}}</:item>
          </DSelect>
        </template>
      );

      assert
        .dom(".ro-btn")
        .hasAria(
          "disabled",
          "true",
          "a readonly button announces its unavailable state via aria-disabled"
        )
        .doesNotHaveAttribute(
          "aria-readonly",
          "aria-readonly is not valid on a button role"
        );
    });

    test("locking a control while it is open closes the overlay", async function (assert) {
      class LockHost extends Component {
        @tracked locked = false;

        @action
        lock() {
          this.locked = true;
        }

        <template>
          <button type="button" class="do-lock" {{on "click" this.lock}}>
            lock
          </button>
          <DSelect
            @items={{ITEMS}}
            @value={{1}}
            @variant="static"
            @disabled={{this.locked}}
            @identifier="test-select"
          >
            <:selection as |item|>{{item.name}}</:selection>
            <:item as |item|>{{item.name}}</:item>
          </DSelect>
        </template>
      }

      await render(<template><LockHost /></template>);

      await click("[role='combobox']");
      assert.dom("[role='listbox']").exists("the control opens");

      await click(".do-lock");
      assert
        .dom("[role='listbox']")
        .doesNotExist(
          "becoming disabled while open closes the overlay so its content can't be used"
        );
    });

    test("a locked option ignores activation until it is unlocked", async function (assert) {
      // Closing the overlay on lock is async (it awaits the exit animation), so an option
      // stays mounted and clickable for that window. The lock must therefore gate the
      // activation itself — the single path pointer and keyboard share — not only the close.
      let value = null;
      const engine = new SelectEngine({
        getValue: () => value,
        onChange: (next) => (value = next),
      });
      const descriptor = engine.buildItems(ITEMS)[1];

      class LockedItemHost extends Component {
        @tracked locked = true;

        @action
        unlock() {
          this.locked = false;
        }

        <template>
          <button type="button" class="do-unlock" {{on "click" this.unlock}}>
            unlock
          </button>
          <ul role="listbox">
            <SelectItem
              @engine={{engine}}
              @descriptor={{descriptor}}
              @locked={{this.locked}}
            >
              {{descriptor.item.name}}
            </SelectItem>
          </ul>
        </template>
      }

      await render(<template><LockedItemHost /></template>);

      await click("[role='option']");
      assert.strictEqual(
        value,
        null,
        "activating a locked option does not change the value"
      );

      await click(".do-unlock");
      await click("[role='option']");
      assert.strictEqual(
        value,
        2,
        "the same option activates once the lock is lifted"
      );
    });

    test("multi-select removes the last chip on Backspace only, never Delete", async function (assert) {
      class MultiDeleteHost extends Component {
        @tracked value = [1, 2];

        @action
        onChange(v) {
          this.value = v;
        }

        <template>
          <DSelect
            @items={{ITEMS}}
            @multiple={{true}}
            @value={{this.value}}
            @onChange={{this.onChange}}
            @identifier="test-select"
          >
            <:selection as |item|>{{item.name}}</:selection>
            <:item as |item|>{{item.name}}</:item>
          </DSelect>
        </template>
      }

      await render(<template><MultiDeleteHost /></template>);
      assert
        .dom(".d-combobox__chip")
        .exists({ count: 2 }, "two chips to start");

      await triggerKeyEvent("[role='combobox']", "keydown", "Delete");
      assert
        .dom(".d-combobox__chip")
        .exists(
          { count: 2 },
          "Delete (forward-delete) leaves the chips: nothing sits after the caret"
        );

      await triggerKeyEvent("[role='combobox']", "keydown", "Backspace");
      assert
        .dom(".d-combobox__chip")
        .exists(
          { count: 1 },
          "Backspace deletes backward toward the chip before the caret, the token-input convention"
        );
    });
  }
);

module(
  "Integration | ui-kit | select | DSelect (re-selection)",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.afterEach(function () {
      clearCallbacks();
      resetLegacyBridge();
    });

    test("Enter on the restored selection closes without emitting a change", async function (assert) {
      // Restoring the cursor to the selected option makes Enter the first keystroke after
      // opening. Leaving it inert (no change, no close) would read as a broken control.
      let changes = 0;
      const onChange = () => changes++;

      await render(
        <template>
          <DSelect @items={{ITEMS}} @value={{2}} @onChange={{onChange}} />
        </template>
      );

      await click("[role='combobox']");
      assert.dom("[role='option'].--active").hasText("Banana");

      await triggerKeyEvent("[role='combobox']", "keydown", "Enter");

      assert.dom("[role='listbox']").doesNotExist("the overlay closes");
      assert.strictEqual(changes, 0, "re-picking the same value emits nothing");
    });

    test("clicking the already-selected option closes without emitting a change", async function (assert) {
      // Enter and the pointer share one activation path, so they must agree.
      let changes = 0;
      const onChange = () => changes++;

      await render(
        <template>
          <DSelect @items={{ITEMS}} @value={{2}} @onChange={{onChange}} />
        </template>
      );

      await click("[role='combobox']");
      await click("[role='option'].--active");

      assert.dom("[role='listbox']").doesNotExist("the overlay closes");
      assert.strictEqual(changes, 0, "no change is emitted");
    });

    test("selecting the current value while closed does not steal focus", async function (assert) {
      // The compat bridge lets a consumer dismiss the overlay, await a request, and only then
      // call select() — by which time the user has moved on. Closing an already-closed menu
      // would focus its trigger and pull them back.
      let selectKit;
      withPluginApi((api) => {
        api.modifySelectKit("test-select").prependContent(() => ({
          id: "act",
          name: "Act now",
          onSelect: (facade) => (selectKit = facade),
        }));
      });

      await render(
        <template>
          <input class="elsewhere" />
          <DSelect @items={{ITEMS}} @value={{2}} @identifier="test-select" />
        </template>
      );

      await click("[role='combobox']");
      // An action row captures the facade without selecting or closing.
      await click("[role='option']");
      await triggerKeyEvent("[role='combobox']", "keydown", "Escape");
      assert.dom("[role='listbox']").doesNotExist("the overlay is closed");

      await focus(".elsewhere");
      selectKit.select(2, { id: 2, name: "Banana" });
      await settled();

      assert.dom(".elsewhere").isFocused("focus stays where the user put it");
    });
  }
);

module("Integration | ui-kit | select | DSelect (:footer)", function (hooks) {
  setupRenderingTest(hooks);

  test("the :footer block renders as a labeled region below the listbox", async function (assert) {
    await render(
      <template>
        <DSelect @items={{ITEMS}}>
          <:footer>
            <button type="button" class="test-footer-btn">Act</button>
          </:footer>
        </DSelect>
      </template>
    );
    await click("[role='combobox']");

    assert
      .dom(".d-combobox__panel > .d-combobox__footer")
      .exists("the footer is a panel child, pinned below the list");
    assert.dom(".d-combobox__footer").hasAttribute("role", "group");
    assert.dom(".d-combobox__footer").hasAttribute("aria-label", /.+/);
    assert
      .dom("[role='listbox'] .d-combobox__footer")
      .doesNotExist("the footer is NOT inside the listbox");
    assert.dom(".d-combobox__footer .test-footer-btn").exists();
  });

  test("the footer's controls are keyboard-reachable focusables inside the popup content", async function (assert) {
    // float-kit's `forwardTabToContent` focuses the first focusable inside the popup content on
    // Tab from the trigger; the footer's control must therefore live in the content region and
    // be focusable, and focusing it (as the forward does) must keep the menu open.
    await render(
      <template>
        <DSelect @items={{ITEMS}}>
          <:footer>
            <button type="button" class="test-footer-btn">Act</button>
          </:footer>
        </DSelect>
      </template>
    );
    await click("[role='combobox']");

    const btn = find(".d-combobox__footer .test-footer-btn");
    assert.true(
      find("[data-content]").contains(btn),
      "the footer control lives inside the popup content region float-kit forwards Tab into"
    );

    btn.focus();
    await settled();
    assert
      .dom("[role='listbox']")
      .exists("focusing the footer control keeps the menu open");
  });

  test("clicking the footer keeps the menu open", async function (assert) {
    await render(
      <template>
        <DSelect @items={{ITEMS}}>
          <:footer>
            <button type="button" class="test-footer-btn">Act</button>
          </:footer>
        </DSelect>
      </template>
    );
    await click("[role='combobox']");
    await click(".test-footer-btn");

    assert
      .dom("[role='listbox']")
      .exists("a footer click does not dismiss the menu");
  });

  test("desktop: focus leaving the footer to outside the widget closes the menu", async function (assert) {
    await render(
      <template>
        <button type="button" class="outside-btn">outside</button>
        <DSelect @items={{ITEMS}}>
          <:footer>
            <button type="button" class="test-footer-btn">Act</button>
          </:footer>
        </DSelect>
      </template>
    );
    await click("[role='combobox']");
    const footerBtn = find(".test-footer-btn");
    footerBtn.focus();
    await triggerEvent(footerBtn, "focusout", {
      relatedTarget: find(".outside-btn"),
    });

    assert
      .dom("[role='listbox']")
      .doesNotExist(
        "focus leaving the footer to an outside control closes the menu"
      );
  });

  test("desktop: focus moving within the footer or back to the input keeps the menu open", async function (assert) {
    await render(
      <template>
        <DSelect @items={{ITEMS}}>
          <:footer>
            <button type="button" class="test-footer-btn">Act</button>
            <button type="button" class="test-footer-btn2">Act2</button>
          </:footer>
        </DSelect>
      </template>
    );
    await click("[role='combobox']");
    const btn1 = find(".test-footer-btn");
    btn1.focus();

    await triggerEvent(btn1, "focusout", {
      relatedTarget: find(".test-footer-btn2"),
    });
    assert
      .dom("[role='listbox']")
      .exists("an intra-footer focus move stays open");

    await triggerEvent(btn1, "focusout", {
      relatedTarget: find("[role='combobox']"),
    });
    assert.dom("[role='listbox']").exists("footer → input stays open");
  });

  test("Escape from the footer closes the menu", async function (assert) {
    await render(
      <template>
        <DSelect @items={{ITEMS}}>
          <:footer>
            <button type="button" class="test-footer-btn">Act</button>
          </:footer>
        </DSelect>
      </template>
    );
    await click("[role='combobox']");
    find(".test-footer-btn").focus();
    await triggerKeyEvent(".test-footer-btn", "keydown", "Escape");

    assert
      .dom("[role='listbox']")
      .doesNotExist("Escape from the footer closes");
  });

  test("ArrowDown from the input navigates options and never the footer", async function (assert) {
    await render(
      <template>
        <DSelect @items={{ITEMS}}>
          <:footer>
            <button type="button" class="test-footer-btn">Act</button>
          </:footer>
        </DSelect>
      </template>
    );
    await click("[role='combobox']");
    await triggerKeyEvent("[role='combobox']", "keydown", "ArrowDown");

    const id = find("[role='combobox']").getAttribute("aria-activedescendant");
    const active = id ? document.getElementById(id) : null;
    assert.strictEqual(
      active?.getAttribute("role"),
      "option",
      "arrow navigation stays within the listbox"
    );
  });

  test("the :footer block receives the dropdown state", async function (assert) {
    await render(
      <template>
        <DSelect @items={{ITEMS}} @value={{1}}>
          <:footer as |state|>
            <span class="test-total">{{state.total}}</span>
            <span class="test-hasvalue">{{if state.hasValue "yes" "no"}}</span>
            <button
              type="button"
              class="test-close"
              {{on "click" state.close}}
            >close</button>
          </:footer>
        </DSelect>
      </template>
    );
    await click("[role='combobox']");

    assert
      .dom(".test-total")
      .hasText(String(ITEMS.length), "the full result count is yielded");
    assert.dom(".test-hasvalue").hasText("yes", "hasValue is yielded");

    await click(".test-close");
    assert
      .dom("[role='listbox']")
      .doesNotExist("the yielded close() dismisses the menu");
  });

  test("the yielded loadedCount shares total's population (excludes specials)", async function (assert) {
    const specialItems = () => [{ id: 0, name: "None" }];
    await render(
      <template>
        <DSelect @items={{ITEMS}} @specialItems={{specialItems}}>
          <:footer as |state|>
            <span class="test-total">{{state.total}}</span>
            <span class="test-loaded">{{state.loadedCount}}</span>
          </:footer>
        </DSelect>
      </template>
    );
    await click("[role='combobox']");

    assert.dom(".test-total").hasText("3", "total counts the source options");
    assert
      .dom(".test-loaded")
      .hasText(
        "3",
        "loadedCount matches total's population — the special row is not counted"
      );
  });
});

module(
  "Integration | ui-kit | select | DSelect (:footer, mobile)",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      forceMobile();
    });

    test("moving focus within the footer does NOT close the modal", async function (assert) {
      await render(
        <template>
          <DSelect @items={{ITEMS}}>
            <:footer>
              <button type="button" class="test-footer-btn">Act</button>
              <button type="button" class="test-footer-btn2">Act2</button>
            </:footer>
          </DSelect>
        </template>
      );
      await click(".d-combobox__trigger");
      assert
        .dom(".fk-d-menu-modal .d-combobox__footer")
        .exists("the footer renders inside the modal");

      const btn1 = find(".fk-d-menu-modal .test-footer-btn");
      btn1.focus();
      await triggerEvent(btn1, "focusout", {
        relatedTarget: find(".fk-d-menu-modal .test-footer-btn2"),
      });

      assert
        .dom(".fk-d-menu-modal [role='listbox']")
        .exists("an intra-footer focus move leaves the mobile modal open");
    });
  }
);

module(
  "Integration | ui-kit | select | DSelect (error state)",
  function (hooks) {
    setupRenderingTest(hooks);

    test("the default error state is a muted inline message, not the alert box", async function (assert) {
      const load = () => Promise.reject(new Error("boom"));
      await render(<template><DSelect @load={{load}} /></template>);
      await fillIn("[role='combobox']", "x");

      assert.dom(".d-combobox__error").exists();
      assert
        .dom(".d-combobox__error .d-icon-triangle-exclamation")
        .exists("the error shows a muted icon");
      assert
        .dom(".d-combobox__error [role='alert']")
        .doesNotExist("the heavy alert box is gone");
      assert
        .dom(".d-combobox__retry.btn-flat")
        .exists("the retry is a low-emphasis button");
    });

    test("@retryable={{false}} hides the retry button", async function (assert) {
      const load = () => Promise.reject(new Error("boom"));
      await render(
        <template><DSelect @load={{load}} @retryable={{false}} /></template>
      );
      await fillIn("[role='combobox']", "x");

      assert.dom(".d-combobox__error").exists("the error still renders");
      assert
        .dom(".d-combobox__retry")
        .doesNotExist("a non-retryable source hides the retry");
    });

    test("an :error block replaces the default and its retry action reloads", async function (assert) {
      let calls = 0;
      const load = () => {
        calls++;
        return calls === 1
          ? Promise.reject(new Error("boom"))
          : Promise.resolve([{ id: 1, name: "Apple" }]);
      };
      await render(
        <template>
          <DSelect @load={{load}}>
            <:error as |error retry|>
              <div class="custom-error">{{error.message}}</div>
              <button
                type="button"
                class="custom-retry"
                {{on "click" retry}}
              >go</button>
            </:error>
            <:item as |item|>{{item.name}}</:item>
          </DSelect>
        </template>
      );
      await fillIn("[role='combobox']", "x");

      assert
        .dom(".custom-error")
        .hasText("boom", "the :error block renders with the error");
      assert
        .dom(".d-combobox__error .d-icon-triangle-exclamation")
        .doesNotExist("the default body is replaced by the block");

      await click(".custom-retry");
      assert
        .dom("[role='option']")
        .exists({ count: 1 }, "the yielded retry action reloads the source");
    });
  }
);

class MultiLimitsHost extends Component {
  @tracked value = this.args.value ?? [];

  get items() {
    return this.args.items ?? ITEMS;
  }

  @action
  onChange(value, payload) {
    this.args.onChange?.(value, payload);
    this.value = value;
  }

  <template>
    <DSelect
      @multiple={{true}}
      @items={{this.items}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @maximum={{@maximum}}
      @minimum={{@minimum}}
      @allowCreate={{@allowCreate}}
      @createItem={{@createItem}}
      @clearable={{@clearable}}
      @placeholder="Pick some"
      @identifier="test-multi-limits"
    >
      <:selection as |item|>{{item.name}}</:selection>
      <:item as |item|>{{item.name}}</:item>
    </DSelect>
  </template>
}

function optionWithText(text) {
  return findAll("[role='option']").find((option) =>
    option.textContent.includes(text)
  );
}

module(
  "Integration | ui-kit | select | DSelect (multi limits)",
  function (hooks) {
    setupRenderingTest(hooks);

    test("pointer activation cannot add an ordinary option at @maximum", async function (assert) {
      const onChange = sinon.spy();
      await render(
        <template>
          <MultiLimitsHost
            @value={{array 1 2}}
            @maximum={{2}}
            @onChange={{onChange}}
          />
        </template>
      );
      await click(".d-combobox__input");
      await click(optionWithText("Cherry pie"));

      assert.strictEqual(
        onChange.callCount,
        0,
        "the rejected pointer add emits no onChange"
      );
      assert
        .dom(".d-combobox__chip")
        .exists({ count: 2 }, "the rejected pointer add creates no chip");
    });

    test("Enter cannot add an ordinary option after the value reaches @maximum", async function (assert) {
      const onChange = sinon.spy();
      this.set("value", [1]);

      await render(
        <template>
          <DSelect
            @multiple={{true}}
            @items={{ITEMS}}
            @value={{this.value}}
            @onChange={{onChange}}
            @maximum={{2}}
          />
        </template>
      );
      await click(".d-combobox__input");
      await triggerKeyEvent("[role='combobox']", "keydown", "ArrowDown");
      await triggerKeyEvent("[role='combobox']", "keydown", "ArrowDown");
      assert
        .dom("[role='option'].--active")
        .hasText(
          "Cherry pie",
          "the unselected option is active before the cap is reached"
        );

      // Keep the highlighted row mounted while the controlled value reaches the cap.
      this.value.push(2);
      await triggerKeyEvent("[role='combobox']", "keydown", "Enter");

      assert.strictEqual(
        onChange.callCount,
        0,
        "the rejected Enter add emits no onChange"
      );
    });

    test("Space cannot add an ordinary option after the value reaches @maximum", async function (assert) {
      const onChange = sinon.spy();
      forceMobile();
      this.set("value", [1]);

      await render(
        <template>
          <DSelect
            @multiple={{true}}
            @items={{ITEMS}}
            @value={{this.value}}
            @onChange={{onChange}}
            @maximum={{2}}
            @variant="static"
          />
        </template>
      );
      await click(".d-combobox__trigger");
      await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");
      await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");
      assert
        .dom(document.activeElement)
        .hasText(
          "Cherry pie",
          "the unselected option is active before the cap is reached"
        );

      // Keep the highlighted row mounted while the controlled value reaches the cap.
      this.value.push(2);
      await triggerKeyEvent(document.activeElement, "keydown", " ");

      assert.strictEqual(
        onChange.callCount,
        0,
        "the rejected Space add emits no onChange"
      );
    });

    test("the create-on-the-fly row is disabled and inert at @maximum", async function (assert) {
      const onChange = sinon.spy();
      const createItem = (filter) => ({
        id: filter,
        name: `Create ${filter}`,
        __create: true,
      });
      await render(
        <template>
          <MultiLimitsHost
            @value={{array 1}}
            @maximum={{1}}
            @onChange={{onChange}}
            @allowCreate={{true}}
            @createItem={{createItem}}
          />
        </template>
      );
      await fillIn("[role='combobox']", "dragonfruit");

      assert
        .dom("[role='option'].--create")
        .hasAttribute(
          "aria-disabled",
          "true",
          "the create-on-the-fly row is exposed as disabled at the cap"
        );
      await click("[role='option'].--create");
      assert.strictEqual(
        onChange.callCount,
        0,
        "activating the disabled create row emits no onChange"
      );
    });

    test("at @maximum only unselected ordinary options become disabled", async function (assert) {
      const actionItem = {
        id: "action",
        name: "Run action",
        onSelect() {},
      };
      const items = [...ITEMS, actionItem];
      await render(
        <template>
          <MultiLimitsHost
            @items={{items}}
            @value={{array 1 2}}
            @maximum={{2}}
          />
        </template>
      );
      await click(".d-combobox__input");

      assert
        .dom("[role='option'][aria-selected='false']")
        .exists(
          { count: 2 },
          "the list contains an unselected ordinary row and action row"
        );
      assert
        .dom(optionWithText("Cherry pie"))
        .hasAttribute(
          "aria-disabled",
          "true",
          "an unselected ordinary option is disabled at the cap"
        );
      assert
        .dom(optionWithText("Apple"))
        .doesNotHaveAttribute(
          "aria-disabled",
          "a selected option stays enabled so it can be deselected"
        );
      assert
        .dom(optionWithText("Run action"))
        .doesNotHaveAttribute(
          "aria-disabled",
          "an action row stays enabled because it does not change the value"
        );
    });

    test("an action row still runs at @maximum without changing the selection", async function (assert) {
      const onChange = sinon.spy();
      const onSelect = sinon.spy();
      const items = [...ITEMS, { id: "action", name: "Run action", onSelect }];
      await render(
        <template>
          <MultiLimitsHost
            @items={{items}}
            @value={{array 1 2}}
            @maximum={{2}}
            @onChange={{onChange}}
          />
        </template>
      );
      await click(".d-combobox__input");
      await click(optionWithText("Run action"));

      assert.true(onSelect.calledOnce, "the action callback runs at the cap");
      assert.strictEqual(
        onChange.callCount,
        0,
        "running the action emits no value change"
      );
      assert
        .dom(".d-combobox__chip")
        .exists({ count: 2 }, "running the action leaves the chips unchanged");
    });

    test("an over-maximum controlled value is preserved without a mount change", async function (assert) {
      const onChange = sinon.spy();
      const items = [
        ...ITEMS,
        { id: 4, name: "Date" },
        { id: 5, name: "Elderberry" },
      ];
      await render(
        <template>
          <MultiLimitsHost
            @items={{items}}
            @value={{array 1 2 3 4 5}}
            @maximum={{3}}
            @onChange={{onChange}}
          />
        </template>
      );

      assert
        .dom(".d-combobox__chip")
        .exists(
          { count: 5 },
          "all five pre-seeded values remain rendered as chips"
        );
      assert.strictEqual(
        onChange.callCount,
        0,
        "mounting an over-maximum value neither trims nor emits it"
      );
    });

    test("removing from an over-maximum value works but does not reopen additions", async function (assert) {
      const onChange = sinon.spy();
      const items = [
        ...ITEMS,
        { id: 4, name: "Date" },
        { id: 5, name: "Elderberry" },
        { id: 6, name: "Fig" },
      ];
      await render(
        <template>
          <MultiLimitsHost
            @items={{items}}
            @value={{array 1 2 3 4 5}}
            @maximum={{3}}
            @onChange={{onChange}}
          />
        </template>
      );
      await click(".d-combobox__input");
      await click(optionWithText("Apple"));

      assert.deepEqual(
        onChange.firstCall.args[0],
        [2, 3, 4, 5],
        "deselecting one over-maximum option emits the remaining four values"
      );
      assert
        .dom(".d-combobox__chip")
        .exists(
          { count: 4 },
          "the selected option is removed while still over the cap"
        );

      await click(optionWithText("Fig"));
      assert.strictEqual(
        onChange.callCount,
        1,
        "an add remains blocked while the reduced value is still over maximum"
      );
    });

    test("the chip remove button remains enabled at @maximum", async function (assert) {
      const onChange = sinon.spy();
      await render(
        <template>
          <MultiLimitsHost
            @value={{array 1 2}}
            @maximum={{2}}
            @onChange={{onChange}}
          />
        </template>
      );
      await click(".d-combobox__chip .d-combobox__chip-remove");

      assert.deepEqual(
        onChange.firstCall.args[0],
        [2],
        "the chip remove button emits the value without the removed item"
      );
      assert
        .dom(".d-combobox__chip")
        .exists(
          { count: 1 },
          "the chip remove button removes one chip at the cap"
        );
    });

    test("Backspace on a chip remains enabled at @maximum", async function (assert) {
      const onChange = sinon.spy();
      await render(
        <template>
          <MultiLimitsHost
            @value={{array 1 2}}
            @maximum={{2}}
            @onChange={{onChange}}
          />
        </template>
      );
      await triggerKeyEvent(
        ".d-combobox__chip .d-combobox__chip-remove",
        "keydown",
        "Backspace"
      );

      assert.deepEqual(
        onChange.firstCall.args[0],
        [2],
        "chip Backspace emits the value without the focused chip"
      );
    });

    test("Delete on a chip remains enabled at @maximum", async function (assert) {
      const onChange = sinon.spy();
      await render(
        <template>
          <MultiLimitsHost
            @value={{array 1 2}}
            @maximum={{2}}
            @onChange={{onChange}}
          />
        </template>
      );
      await triggerKeyEvent(
        ".d-combobox__chip .d-combobox__chip-remove",
        "keydown",
        "Delete"
      );

      assert.deepEqual(
        onChange.firstCall.args[0],
        [2],
        "chip Delete emits the value without the focused chip"
      );
    });

    test("Backspace on an empty query remains enabled at @maximum", async function (assert) {
      const onChange = sinon.spy();
      await render(
        <template>
          <MultiLimitsHost
            @value={{array 1 2}}
            @maximum={{2}}
            @onChange={{onChange}}
          />
        </template>
      );
      await triggerKeyEvent("[role='combobox']", "keydown", "Backspace");

      assert.deepEqual(
        onChange.firstCall.args[0],
        [1],
        "empty-query Backspace removes the last selected value at the cap"
      );
    });

    test("clear-all remains enabled at @maximum", async function (assert) {
      const onChange = sinon.spy();
      await render(
        <template>
          <MultiLimitsHost
            @value={{array 1 2}}
            @maximum={{2}}
            @clearable={{true}}
            @onChange={{onChange}}
          />
        </template>
      );
      await click(".d-combobox__clear");

      assert.deepEqual(
        onChange.firstCall.args[0],
        [],
        "clear-all emits an empty multi-select value at the cap"
      );
      assert
        .dom(".d-combobox__chip")
        .doesNotExist("clear-all removes every chip at the cap");
    });

    test("a null value entry consumes a @maximum slot that removing its chip reclaims", async function (assert) {
      const onChange = sinon.spy();
      await render(
        <template>
          <MultiLimitsHost
            @value={{array null 1}}
            @maximum={{2}}
            @onChange={{onChange}}
          />
        </template>
      );

      // A null still renders its own removable chip, so it occupies a slot like any other held
      // value — counting it is what keeps the visible selection from outgrowing the cap.
      assert
        .dom(".d-combobox__chip")
        .exists({ count: 2 }, "the null entry renders a chip of its own");

      await click(".d-combobox__input");
      assert
        .dom(optionWithText("Banana"))
        .hasAttribute(
          "aria-disabled",
          "true",
          "the null entry fills the last slot, so adding is refused"
        );
      await click(optionWithText("Banana"));
      assert.strictEqual(
        onChange.callCount,
        0,
        "the refused add emits no onChange"
      );

      // The slot is reclaimable, so a null can never wedge the control at its cap.
      await click(".d-combobox__chip .d-combobox__chip-remove");
      assert.deepEqual(
        onChange.firstCall.args[0],
        [1],
        "removing the null chip frees its slot"
      );
    });

    test("zero and negative @maximum values are uncapped", async function (assert) {
      const zeroChange = sinon.spy();
      const negativeChange = sinon.spy();
      await render(
        <template>
          <div class="zero-maximum">
            <MultiLimitsHost
              @value={{array 1}}
              @maximum={{0}}
              @onChange={{zeroChange}}
            />
          </div>
          <div class="negative-maximum">
            <MultiLimitsHost
              @value={{array 1}}
              @maximum={{-1}}
              @onChange={{negativeChange}}
            />
          </div>
        </template>
      );

      await click(".zero-maximum .d-combobox__input");
      await click(".zero-maximum [role='option'][aria-selected='false']");
      assert.true(
        zeroChange.calledOnce,
        "@maximum={{0}} allows an additional selection"
      );

      await click(".negative-maximum .d-combobox__input");
      await click(".negative-maximum [role='option'][aria-selected='false']");
      assert.true(
        negativeChange.calledOnce,
        "a negative @maximum allows an additional selection"
      );
    });

    test("option deselection can go below @minimum to zero", async function (assert) {
      const onChange = sinon.spy();
      await render(
        <template>
          <MultiLimitsHost
            @value={{array 1}}
            @minimum={{3}}
            @onChange={{onChange}}
          />
        </template>
      );
      await click(".d-combobox__input");
      await click("[role='option'][aria-selected='true']");

      assert.deepEqual(
        onChange.firstCall.args[0],
        [],
        "deselecting the last option emits zero selections below minimum"
      );
      assert
        .dom(".d-combobox__chip")
        .doesNotExist("the final chip is removed below minimum");
    });

    test("clear-all can go below @minimum to zero", async function (assert) {
      const onChange = sinon.spy();
      await render(
        <template>
          <MultiLimitsHost
            @value={{array 1 2}}
            @minimum={{3}}
            @clearable={{true}}
            @onChange={{onChange}}
          />
        </template>
      );
      await click(".d-combobox__clear");

      assert.deepEqual(
        onChange.firstCall.args[0],
        [],
        "clear-all emits zero selections below minimum"
      );
      assert
        .dom(".d-combobox__chip")
        .doesNotExist("clear-all removes every chip below minimum");
    });

    test("single-select ignores @maximum and @minimum completely", async function (assert) {
      class SingleLimitsHost extends Component {
        @tracked value = 1;

        @action
        onChange(value, payload) {
          this.args.onChange(value, payload);
          this.value = value;
        }

        <template>
          <DSelect
            @items={{ITEMS}}
            @value={{this.value}}
            @onChange={{this.onChange}}
            @maximum={{1}}
            @minimum={{3}}
          />
        </template>
      }

      const onChange = sinon.spy();
      await render(
        <template><SingleLimitsHost @onChange={{onChange}} /></template>
      );
      await click("[role='combobox']");

      assert
        .dom("[role='option'][aria-selected='false']")
        .doesNotHaveAttribute(
          "aria-disabled",
          "single-select options are not disabled by multi-select limits"
        );
      await click(optionWithText("Banana"));
      assert.strictEqual(
        onChange.firstCall.args[0],
        2,
        "single-select still replaces its value normally"
      );
      assert
        .dom("[role='combobox']")
        .hasValue("Banana", "single-select renders the replacement normally");
    });
  }
);

module(
  "Integration | ui-kit | select | DSelect (multi limit engine state)",
  function (hooks) {
    setupRenderingTest(hooks);

    test("the public limit getters reflect the live multi-select count", function (assert) {
      let value = [1];
      const engine = new SelectEngine({
        multiple: true,
        maximum: 3,
        minimum: 2,
        getValue: () => value,
      });

      assert.strictEqual(
        engine.maximum,
        3,
        "maximum exposes the configured cap"
      );
      assert.strictEqual(
        engine.minimum,
        2,
        "minimum exposes the configured floor"
      );
      assert.false(
        engine.atMaximum,
        "one of three selections is not at maximum"
      );
      assert.true(
        engine.belowMinimum,
        "one selection is below the minimum of two"
      );
      assert.strictEqual(engine.remaining, 2, "two cap slots remain");

      value = [1, 2, 3, 4];
      assert.true(
        engine.atMaximum,
        "an over-maximum value is still at maximum"
      );
      assert.false(
        engine.belowMinimum,
        "an over-maximum value is not below minimum"
      );
      assert.strictEqual(
        engine.remaining,
        0,
        "remaining is floored at zero above the cap"
      );
    });

    test("remaining counts null entries and is undefined when uncapped", function (assert) {
      const limited = new SelectEngine({
        multiple: true,
        maximum: 2,
        getValue: () => [null, 1],
      });
      const uncapped = new SelectEngine({
        multiple: true,
        getValue: () => [1],
      });

      // A null entry still resolves to a displayed, removable chip, so it occupies a slot like
      // any other held value — otherwise the visible selection could outgrow the cap.
      assert.strictEqual(
        limited.remaining,
        0,
        "null consumes one of the limited engine's cap slots"
      );
      assert.true(
        limited.atMaximum,
        "a null alongside a real value reaches the cap"
      );
      assert.strictEqual(
        uncapped.remaining,
        undefined,
        "remaining is undefined without a positive maximum"
      );
    });
  }
);

module(
  "Integration | ui-kit | select | DSelect (multi limit compat bridge)",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.afterEach(function () {
      clearCallbacks();
      resetLegacyBridge();
    });

    test("modifySelectKit select() cannot add a value at @maximum", async function (assert) {
      let selectKit;
      const onChange = sinon.spy();
      withPluginApi((api) => {
        api.modifySelectKit("test-multi-limits").prependContent(() => ({
          id: "capture",
          name: "Capture facade",
          onSelect: (facade) => (selectKit = facade),
        }));
      });

      await render(
        <template>
          <MultiLimitsHost
            @value={{array 1 2}}
            @maximum={{2}}
            @onChange={{onChange}}
          />
        </template>
      );
      await click(".d-combobox__input");
      await click(optionWithText("Capture facade"));
      assert.notStrictEqual(
        selectKit,
        undefined,
        "the enabled action row exposes the compat facade"
      );

      selectKit.select(3, ITEMS[2]);
      await settled();

      assert.strictEqual(
        onChange.callCount,
        0,
        "the direct engine.select() bridge call emits no onChange at the cap"
      );
      assert
        .dom(".d-combobox__chip")
        .exists({ count: 2 }, "the compat bridge cannot add a chip at the cap");
    });
  }
);

class MultiLimitsStaticHost extends Component {
  @tracked value = this.args.value ?? [];

  @action
  onChange(value, payload) {
    this.args.onChange?.(value, payload);
    this.value = value;
  }

  <template>
    <DSelect
      @multiple={{true}}
      @items={{@items}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @maximum={{@maximum}}
      @variant="static"
      @placeholder="Pick some"
      @identifier="test-multi-limits-static"
    >
      <:selection as |item|>{{item.name}}</:selection>
      <:item as |item|>{{item.name}}</:item>
    </DSelect>
  </template>
}

class ReactiveMaximumHost extends Component {
  @tracked maximum = 2;
  @tracked value = [1, 3];

  @action
  onChange(value) {
    this.value = value;
  }

  @action
  raiseMaximum() {
    this.maximum = 3;
  }

  @action
  lowerMaximum() {
    this.maximum = 2;
  }

  <template>
    <DSelect
      @multiple={{true}}
      @items={{@items}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @maximum={{this.maximum}}
      @variant="static"
      @identifier="test-reactive-maximum"
    >
      <:selection as |item|>{{item.name}}</:selection>
      <:item as |item|>{{item.name}}</:item>
      <:footer>
        <button
          type="button"
          class="raise-maximum"
          {{on "click" this.raiseMaximum}}
        >Raise maximum</button>
        <button
          type="button"
          class="lower-maximum"
          {{on "click" this.lowerMaximum}}
        >Lower maximum</button>
      </:footer>
    </DSelect>
  </template>
}

class FooterLimitsHost extends Component {
  @tracked value = [1];

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
      @maximum={{3}}
      @minimum={{2}}
      @identifier="test-footer-limits"
    >
      <:footer as |state|>
        <span class="footer-maximum">{{state.maximum}}</span>
        <span class="footer-minimum">{{state.minimum}}</span>
        <span class="footer-at-maximum">
          {{if state.atMaximum "yes" "no"}}
        </span>
        <span class="footer-below-minimum">
          {{if state.belowMinimum "yes" "no"}}
        </span>
        <span class="footer-remaining">{{state.remaining}}</span>
      </:footer>
    </DSelect>
  </template>
}

module(
  "Integration | ui-kit | select | DSelect (multi limits keyboard)",
  function (hooks) {
    setupRenderingTest(hooks);

    test("typeahead open at @maximum is inert until deliberate navigation", async function (assert) {
      const onChange = sinon.spy();
      await render(
        <template>
          <MultiLimitsHost
            @value={{array 1 2}}
            @maximum={{2}}
            @onChange={{onChange}}
          />
        </template>
      );

      await click(".d-combobox__input");
      const controller = find("[role='combobox']");

      assert
        .dom("[role='option'].--active")
        .doesNotExist("opening at the cap does not auto-highlight an option");
      assert.false(
        Boolean(controller.getAttribute("aria-activedescendant")),
        "opening at the cap leaves aria-activedescendant empty"
      );

      await triggerKeyEvent(controller, "keydown", "Enter");

      assert.strictEqual(
        onChange.callCount,
        0,
        "Enter without deliberate navigation emits no value change"
      );
      assert
        .dom(".d-combobox__chip")
        .exists({ count: 2 }, "Enter without a highlight preserves both chips");

      await triggerKeyEvent(controller, "keydown", "ArrowDown");
      assert
        .dom("[role='option'].--active")
        .hasAttribute(
          "aria-selected",
          "true",
          "deliberate navigation highlights a selected option"
        );
      await triggerKeyEvent(controller, "keydown", "Enter");

      assert.strictEqual(
        onChange.callCount,
        1,
        "Enter after deliberate navigation emits one deselection"
      );
      assert
        .dom(".d-combobox__chip")
        .exists(
          { count: 1 },
          "deliberate navigation followed by Enter removes one chip"
        );
    });

    test("desktop static open at @maximum is inert until deliberate navigation", async function (assert) {
      const onChange = sinon.spy();
      await render(
        <template>
          <MultiLimitsStaticHost
            @items={{ITEMS}}
            @value={{array 1 2}}
            @maximum={{2}}
            @onChange={{onChange}}
          />
        </template>
      );

      await click(".d-combobox__trigger");
      const controller = find("[role='combobox']");

      assert
        .dom("[role='option'].--active")
        .doesNotExist("opening static at the cap does not auto-highlight");
      assert.false(
        Boolean(controller.getAttribute("aria-activedescendant")),
        "the static controller has no active descendant on open at the cap"
      );

      await triggerKeyEvent(controller, "keydown", "Enter");

      assert.strictEqual(
        onChange.callCount,
        0,
        "Enter without deliberate static navigation emits no value change"
      );
      assert
        .dom(".d-combobox__chip")
        .exists({ count: 2 }, "the inert Enter preserves both static chips");

      await triggerKeyEvent(controller, "keydown", "ArrowDown");
      assert
        .dom("[role='option'].--active")
        .hasAttribute(
          "aria-selected",
          "true",
          "deliberate static navigation highlights a selected option"
        );
      await triggerKeyEvent(controller, "keydown", "Enter");

      assert.strictEqual(
        onChange.callCount,
        1,
        "Enter after deliberate static navigation emits one deselection"
      );
      assert
        .dom(".d-combobox__chip")
        .exists(
          { count: 1 },
          "deliberate static navigation followed by Enter removes one chip"
        );
    });

    test("arrow navigation skips disabled options at @maximum", async function (assert) {
      const items = [
        ...ITEMS,
        { id: 4, name: "Date" },
        { id: 5, name: "Elderberry" },
      ];
      await render(
        <template>
          <MultiLimitsStaticHost
            @items={{items}}
            @value={{array 1 3 5}}
            @maximum={{3}}
          />
        </template>
      );
      await click(".d-combobox__trigger");

      const controller = find("[role='combobox']");
      for (const [key, expected] of [
        ["ArrowDown", "Apple"],
        ["ArrowDown", "Cherry pie"],
        ["ArrowDown", "Elderberry"],
        ["ArrowUp", "Cherry pie"],
        ["ArrowUp", "Apple"],
      ]) {
        await triggerKeyEvent(controller, "keydown", key);
        const active = find("[role='option'].--active");

        assert
          .dom(active)
          .hasText(expected, `${key} steps to the next enabled selected option`)
          .doesNotHaveAttribute(
            "aria-disabled",
            `${key} never lands on a cap-disabled option`
          );
        assert
          .dom(controller)
          .hasAttribute(
            "aria-activedescendant",
            active.id,
            `${key} points the controller at the enabled active option`
          );
      }
    });

    test("jump keys address only enabled options at @maximum", async function (assert) {
      const items = Array.from({ length: 8 }, (_, index) => ({
        id: index + 1,
        name: `Item ${index + 1}`,
      }));
      await render(
        <template>
          <MultiLimitsStaticHost
            @items={{items}}
            @value={{array 2 7}}
            @maximum={{2}}
          />
        </template>
      );
      await click(".d-combobox__trigger");

      const controller = find("[role='combobox']");
      for (const [key, expected] of [
        ["End", "Item 7"],
        ["Home", "Item 2"],
        ["PageDown", "Item 7"],
        ["PageUp", "Item 2"],
      ]) {
        await triggerKeyEvent(controller, "keydown", key);
        const active = find("[role='option'].--active");

        assert
          .dom(active)
          .hasText(
            expected,
            `${key} resolves against the enabled logical option set`
          )
          .doesNotHaveAttribute(
            "aria-disabled",
            `${key} never lands on a cap-disabled row`
          );
        assert
          .dom(controller)
          .hasAttribute(
            "aria-activedescendant",
            active.id,
            `${key} leaves a resolvable active descendant`
          );
      }
    });

    test("changing @maximum updates disabled rows and navigation without reopening", async function (assert) {
      const items = [
        ...ITEMS,
        { id: 4, name: "Date" },
        { id: 5, name: "Elderberry" },
      ];
      await render(
        <template><ReactiveMaximumHost @items={{items}} /></template>
      );
      await click(".d-combobox__trigger");

      const controller = find("[role='combobox']");
      const listbox = find("[role='listbox']");
      assert
        .dom(optionWithText("Banana"))
        .hasAttribute(
          "aria-disabled",
          "true",
          "an unselected option starts disabled at the cap"
        );

      await click(".raise-maximum");

      assert.strictEqual(
        find("[role='listbox']"),
        listbox,
        "raising the tracked maximum keeps the existing listbox open"
      );
      assert
        .dom(optionWithText("Banana"))
        .doesNotHaveAttribute(
          "aria-disabled",
          "raising the maximum immediately enables an unselected option"
        );
      await triggerKeyEvent(controller, "keydown", "Home");
      await triggerKeyEvent(controller, "keydown", "ArrowDown");
      assert
        .dom("[role='option'].--active")
        .hasText(
          "Banana",
          "the newly enabled option is immediately keyboard-navigable"
        )
        .doesNotHaveAttribute(
          "aria-disabled",
          "navigation lands on the newly enabled row"
        );

      await click(".lower-maximum");

      assert.strictEqual(
        find("[role='listbox']"),
        listbox,
        "lowering the tracked maximum also keeps the listbox open"
      );
      assert
        .dom(optionWithText("Banana"))
        .hasAttribute(
          "aria-disabled",
          "true",
          "lowering back to the cap immediately re-disables the option"
        );
      assert
        .dom("[role='option'][aria-disabled='true'].--active")
        .doesNotExist(
          "lowering the cap does not leave the roving highlight on a disabled row"
        );
    });
  }
);

module(
  "Integration | ui-kit | select | DSelect (multi limits messages)",
  function (hooks) {
    setupRenderingTest(hooks);

    test("the maximum limit message renders as a status above the listbox", async function (assert) {
      await render(
        <template>
          <MultiLimitsHost @value={{array 1 2}} @maximum={{2}} />
        </template>
      );
      await click(".d-combobox__input");

      const panel = find(".d-combobox__panel");
      const limit = find(".d-combobox__limit");
      const listbox = find("[role='listbox']");

      assert
        .dom(limit)
        .hasAttribute("role", "status", "the cap message is a status region")
        .hasText(
          i18n("d_select.max_reached", { count: 2 }),
          "the cap status contains the resolved maximum message"
        );
      assert.true(
        panel.contains(limit),
        "the limit status is inside the panel"
      );
      assert.true(panel.contains(listbox), "the listbox is inside the panel");
      assert.strictEqual(
        limit.compareDocumentPosition(listbox),
        Node.DOCUMENT_POSITION_FOLLOWING,
        "the limit status precedes the listbox in panel DOM order"
      );
    });

    test("the minimum limit message renders below @minimum", async function (assert) {
      await render(
        <template>
          <MultiLimitsHost @value={{array 1}} @minimum={{2}} />
        </template>
      );
      await click(".d-combobox__input");

      assert
        .dom(".d-combobox__limit")
        .hasAttribute(
          "role",
          "status",
          "the below-minimum message is a status region"
        )
        .hasText(
          i18n("d_select.min_not_reached", { count: 2 }),
          "the status contains the resolved minimum message"
        );
    });

    test("single-select never renders a multi-limit message", async function (assert) {
      await render(
        <template>
          <DSelect
            @items={{ITEMS}}
            @value={{1}}
            @maximum={{1}}
            @minimum={{3}}
          />
        </template>
      );
      await click("[role='combobox']");

      assert
        .dom(".d-combobox__limit")
        .doesNotExist(
          "single-select ignores maximum and minimum message state"
        );
    });

    test("the limit message is suppressed below @minChars", async function (assert) {
      await render(
        <template>
          <DSelect
            @multiple={{true}}
            @items={{ITEMS}}
            @value={{array 1 2}}
            @maximum={{2}}
            @minChars={{3}}
          />
        </template>
      );
      await fillIn("[role='combobox']", "a");

      assert
        .dom(".d-combobox__limit")
        .doesNotExist(
          "the cap message is hidden while the query is below minChars"
        );
      assert
        .dom(".d-combobox__min-chars")
        .hasAttribute(
          "role",
          "status",
          "the min-chars hint remains visible as the relevant status"
        );
    });
  }
);

module(
  "Integration | ui-kit | select | DSelect (multi limits footer hash)",
  function (hooks) {
    setupRenderingTest(hooks);

    test("the :footer hash exposes live limit state below and at the cap", async function (assert) {
      await render(<template><FooterLimitsHost /></template>);
      await click(".d-combobox__input");

      assert
        .dom(".footer-maximum")
        .hasText("3", "maximum exposes the configured cap");
      assert
        .dom(".footer-minimum")
        .hasText("2", "minimum exposes the configured floor");
      assert
        .dom(".footer-at-maximum")
        .hasText("no", "atMaximum is false below the cap");
      assert
        .dom(".footer-below-minimum")
        .hasText("yes", "belowMinimum is true below the floor");
      assert
        .dom(".footer-remaining")
        .hasText("2", "remaining exposes the two available slots");

      await click(optionWithText("Banana"));
      await click(optionWithText("Cherry pie"));

      assert
        .dom(".footer-maximum")
        .hasText("3", "maximum remains stable at the cap");
      assert
        .dom(".footer-minimum")
        .hasText("2", "minimum remains stable at the cap");
      assert
        .dom(".footer-at-maximum")
        .hasText("yes", "atMaximum reacts when the cap is reached");
      assert
        .dom(".footer-below-minimum")
        .hasText("no", "belowMinimum clears once the floor is reached");
      assert
        .dom(".footer-remaining")
        .hasText("0", "remaining reaches zero at the cap");
    });
  }
);
