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
  resetOnerror,
  settled,
  setupOnerror,
  triggerKeyEvent,
  waitFor,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { forceMobile } from "discourse/lib/mobile";
import { capabilities } from "discourse/services/capabilities";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  Host,
  ITEMS,
  optionWithText,
} from "discourse/tests/helpers/d-select-hosts";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";

// A controlled host that forwards the trigger-frame args (icon / caret / clear / lock).
class FrameHost extends Component {
  @tracked value = this.args.value ?? (this.args.multiple ? [] : null);

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @caretIcon={{@caretIcon}}
      @clearable={{@clearable}}
      @disabled={{@disabled}}
      @icon={{@icon}}
      @identifier="test-select"
      @items={{ITEMS}}
      @multiple={{@multiple}}
      @onChange={{this.onChange}}
      @readonly={{@readonly}}
      @value={{this.value}}
      @variant={{@variant}}
    >
      <:selection as |item|>{{item.name}}</:selection>
      <:item as |item|>{{item.name}}</:item>
    </DSelect>
  </template>
}

module(
  "Integration | ui-kit | select | DSelect (@selectedIcon)",
  function (hooks) {
    setupRenderingTest(hooks);

    test("a single-select renders @selectedIcon on the selected option", async function (assert) {
      await render(
        <template>
          <DSelect @items={{ITEMS}} @selectedIcon="star" @value={{1}} />
        </template>
      );
      await click("[role='combobox']");

      assert
        .dom(
          "[role='option'][aria-selected='true'] .d-select__option-selected-icon.d-icon-star"
        )
        .exists("the selected row carries the custom icon in single-select");
    });

    test("a single-select without @selectedIcon renders no selected-option icon", async function (assert) {
      await render(
        <template><DSelect @items={{ITEMS}} @value={{1}} /></template>
      );
      await click("[role='combobox']");

      assert
        .dom(".d-select__option-selected-icon")
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
        .dom(".d-select__caret")
        .exists("the trigger shows a caret without @showCaret");
    });

    test("@showCaret={{false}} suppresses the caret", async function (assert) {
      await render(
        <template><DSelect @items={{ITEMS}} @showCaret={{false}} /></template>
      );

      assert
        .dom(".d-select__caret")
        .doesNotExist("the caret is hidden when @showCaret is false");
    });
  }
);

module(
  "Integration | ui-kit | select | DSelect (frame args)",
  function (hooks) {
    setupRenderingTest(hooks);

    // The same hazard as a chip's remove button, one control over: on the button and static
    // variants the yielded value is a span, so the clear button becomes the first LABELABLE
    // descendant and an enclosing label forwards its clicks straight to it. Clicking a field's
    // caption would then wipe the selection.
    test("a surrounding label does not clear the value", async function (assert) {
      await render(
        <template>
          <label class="field-label">
            <span class="field-text">Choice</span>
            <FrameHost @clearable={{true}} @value={{1}} @variant="button" />
          </label>
        </template>
      );

      assert.dom(".d-select__clear").exists("the clear control is present");
      assert.strictEqual(
        find(".field-label").control,
        find(".d-select__label-sink"),
        "the label's control is the sink, not the clear button"
      );

      await click(".field-text");
      assert
        .dom(".d-select__value")
        .hasText("Apple", "clicking the label's text keeps the selection");
    });

    // The panel is portaled out of the trigger, so anything a consumer puts in a footer sits
    // outside an enclosing label and cannot be reached by its click forwarding.
    test("a surrounding label cannot reach a footer button", async function (assert) {
      let footerClicks = 0;
      const onFooter = () => (footerClicks += 1);

      await render(
        <template>
          <label class="field-label">
            <span class="field-text">Choice</span>
            <DSelect @identifier="test-footer" @items={{ITEMS}} @value={{1}}>
              <:footer>
                <button
                  class="footer-action"
                  type="button"
                  {{on "click" onFooter}}
                >
                  Act
                </button>
              </:footer>
            </DSelect>
          </label>
        </template>
      );

      await click("[role='combobox']");
      assert.dom(".footer-action").exists("the footer button is rendered");

      await click(".field-text");
      assert.strictEqual(
        footerClicks,
        0,
        "the label never activates a control inside the panel"
      );
    });

    // Taking the label association is only half the job: having taken it, the sink owes the
    // field the behaviour a label normally provides.
    test("a surrounding label focuses the query input without opening the panel", async function (assert) {
      await render(
        <template>
          <label class="field-label">
            <span class="field-text">Choice</span>
            <FrameHost @value={{1}} />
          </label>
        </template>
      );

      await click(".field-text");
      assert.strictEqual(
        document.activeElement,
        find(".d-select__input"),
        "the query input takes focus"
      );
      assert
        .dom("[role='listbox']")
        .doesNotExist("clicking the caption does not open the panel");
    });

    // Focus alone would leave the caret wherever a programmatic focus drops it, and the
    // overtype select-all that a keyboard focus performs is wrong for a pointer. Rendered
    // without a selection block so the input carries the label text to put a caret in.
    test("a surrounding label places the caret rather than selecting the label", async function (assert) {
      await render(
        <template>
          <label class="field-label">
            <span class="field-text">Choice</span>
            <DSelect @identifier="test-caret" @items={{ITEMS}} @value={{1}} />
          </label>
        </template>
      );

      await click(".field-text");
      const input = find(".d-select__input");
      assert.strictEqual(input.value, "Apple", "the input shows the selection");
      // Asserted together: an untouched input already reports a collapsed caret at the end,
      // so the selection assertions only mean something once focus has actually landed.
      assert.strictEqual(document.activeElement, input, "the input has focus");
      assert.strictEqual(
        input.selectionStart,
        input.value.length,
        "the caret sits after the label"
      );
      assert.strictEqual(
        input.selectionEnd,
        input.value.length,
        "nothing is selected for overtype"
      );
    });

    // The button and static variants have no inner input, so the controller is the trigger.
    test("a surrounding label focuses a button trigger", async function (assert) {
      await render(
        <template>
          <label class="field-label">
            <span class="field-text">Choice</span>
            <FrameHost @value={{1}} @variant="button" />
          </label>
        </template>
      );

      await click(".field-text");
      assert.strictEqual(
        document.activeElement,
        find(".d-select__trigger"),
        "the trigger takes focus"
      );
    });

    test("a surrounding label does not focus a disabled select", async function (assert) {
      await render(
        <template>
          <label class="field-label">
            <span class="field-text">Choice</span>
            <FrameHost @disabled={{true}} @value={{1}} />
          </label>
        </template>
      );

      await click(".field-text");
      assert.false(
        find(".d-select").contains(document.activeElement),
        "focus stays outside a locked control"
      );
    });

    test("@clearable shows a clear control only when there is a value, and clearing it does not open the menu", async function (assert) {
      await render(
        <template><FrameHost @clearable={{true}} @value={{1}} /></template>
      );

      assert
        .dom(".d-select__clear")
        .exists("the clear control shows while a value is selected")
        .hasAria(
          "label",
          "Clear selection",
          "single-select names it 'Clear selection'"
        );

      await click(".d-select__clear");

      assert
        .dom(".d-select__clear")
        .doesNotExist("clearing removes the value, so the control hides");
      assert
        .dom("[role='listbox']")
        .doesNotExist("the clear click does not bubble up to open the overlay");
    });

    test("@clearable is absent when nothing is selected", async function (assert) {
      await render(<template><FrameHost @clearable={{true}} /></template>);

      assert
        .dom(".d-select__clear")
        .doesNotExist("no clear control while the selection is empty");
    });

    test("@clearable stays out of the tab order and restores trigger focus after pointer clearing", async function (assert) {
      await render(
        <template>
          <FrameHost @clearable={{true}} @value={{1}} @variant="static" />
        </template>
      );

      assert
        .dom(".d-select__clear")
        .hasAttribute(
          "tabindex",
          "-1",
          "the pointer affordance is not a tab stop"
        );

      await click(".d-select__clear");

      assert
        .dom(".d-select__trigger")
        .isFocused("focus returns to the static combobox controller");
    });

    test("@clearable on multi clears every chip and names itself 'Clear all'", async function (assert) {
      await render(
        <template>
          <FrameHost
            @clearable={{true}}
            @multiple={{true}}
            @value={{array 1 2}}
          />
        </template>
      );

      assert.dom(".d-select__chip").exists({ count: 2 }, "two chips to start");
      assert
        .dom(".d-select__clear")
        .hasAria("label", "Clear all", "multi-select names it 'Clear all'");

      await click(".d-select__clear");

      assert.dom(".d-select__chip").doesNotExist("clearing removes every chip");
    });

    test("@clearable clears a static control from the keyboard (Delete)", async function (assert) {
      await render(
        <template>
          <FrameHost @clearable={{true}} @value={{1}} @variant="static" />
        </template>
      );

      const trigger = find("[role='combobox']");
      await focus(trigger);
      await triggerKeyEvent(trigger, "keydown", "Delete");

      assert
        .dom(".d-select__value")
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
          <FrameHost @icon="tag" @value={{1}} @variant="static" />
        </template>
      );

      assert
        .dom(".d-select__leading-icon")
        .exists("the leading icon renders")
        .hasClass("d-icon-tag", "it is the requested glyph");
    });

    test("@caretIcon hash swaps the caret between the open and closed glyphs", async function (assert) {
      await render(
        <template>
          <FrameHost
            @caretIcon={{hash open="chevron-up" closed="chevron-down"}}
            @value={{1}}
            @variant="static"
          />
        </template>
      );

      assert
        .dom(".d-select__caret")
        .hasClass("d-icon-chevron-down", "closed shows the closed glyph");

      await click("[role='combobox']");

      assert
        .dom(".d-select__caret")
        .hasClass("d-icon-chevron-up", "open swaps to the open glyph");
    });

    test("@caretIcon string uses one glyph in both states", async function (assert) {
      await render(
        <template>
          <FrameHost @caretIcon="caret-down" @value={{1}} @variant="static" />
        </template>
      );

      assert.dom(".d-select__caret").hasClass("d-icon-caret-down");

      await click("[role='combobox']");

      assert
        .dom(".d-select__caret")
        .hasClass("d-icon-caret-down", "the same glyph stays while open");
    });

    test("@caretIcon with only an open glyph falls back to the default closed glyph", async function (assert) {
      await render(
        <template>
          <FrameHost
            @caretIcon={{hash open="chevron-up"}}
            @value={{1}}
            @variant="static"
          />
        </template>
      );

      assert
        .dom(".d-select__caret")
        .hasClass(
          "d-icon-angle-down",
          "the missing closed side uses the default"
        );

      await click("[role='combobox']");

      assert
        .dom(".d-select__caret")
        .hasClass("d-icon-chevron-up", "the supplied open side is preserved");
    });

    test("@caretIcon with only a closed glyph falls back to the default open glyph", async function (assert) {
      await render(
        <template>
          <FrameHost
            @caretIcon={{hash closed="chevron-down"}}
            @value={{1}}
            @variant="static"
          />
        </template>
      );

      assert
        .dom(".d-select__caret")
        .hasClass(
          "d-icon-chevron-down",
          "the supplied closed side is preserved"
        );

      await click("[role='combobox']");

      assert
        .dom(".d-select__caret")
        .hasClass("d-icon-angle-up", "the missing open side uses the default");
    });

    test("the caret remains the last trigger child when a clear control is present", async function (assert) {
      await render(
        <template>
          <FrameHost @clearable={{true}} @value={{1}} />
          <FrameHost @clearable={{true}} @value={{1}} @variant="button" />
          <FrameHost @clearable={{true}} @value={{1}} @variant="static" />
          <FrameHost
            @clearable={{true}}
            @multiple={{true}}
            @value={{array 1 2}}
          />
        </template>
      );

      for (const trigger of findAll(".d-select__trigger")) {
        assert.true(
          trigger.lastElementChild?.classList.contains("d-select__caret"),
          "the caret is the trigger's last element child"
        );
        assert.true(
          trigger.lastElementChild?.previousElementSibling?.classList.contains(
            "d-select__clear"
          ),
          "the clear button immediately precedes the caret"
        );
      }
    });

    test("@disabled makes the control inert: not focusable, cannot open, no clear", async function (assert) {
      await render(
        <template>
          <FrameHost
            @clearable={{true}}
            @disabled={{true}}
            @value={{1}}
            @variant="static"
          />
        </template>
      );

      assert
        .dom("[role='combobox']")
        .hasAria("disabled", "true", "the control is marked aria-disabled")
        .doesNotHaveAttribute("tabindex", "and dropped from the tab order");
      assert
        .dom(".d-select__clear")
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
            @disabled={{true}}
            @multiple={{true}}
            @value={{array 1 2}}
          />
        </template>
      );

      const removeButton = find(".d-select__chip-remove");
      assert
        .dom(removeButton)
        .isNotDisabled("the chip remains focusable")
        .hasAria("disabled", "true", "removal is unavailable");

      await click(".d-select__trigger");

      assert
        .dom(".d-select__chip")
        .exists({ count: 2 }, "the disabled selection remains unchanged");
      assert
        .dom("[role='listbox']")
        .doesNotExist("the locked multi select stays closed");
    });

    test("@readonly stays focusable but cannot open or edit", async function (assert) {
      await render(
        <template>
          <FrameHost @readonly={{true}} @value={{1}} @variant="static" />
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
        .dom(".d-select__presentation")
        .hasText("Apple", "the selected value remains readable");

      await focus(input);
      assert.dom(input).isFocused("the readonly input can receive focus");

      await triggerKeyEvent(input, "keydown", "ArrowDown");
      await triggerKeyEvent(input, "keydown", "X");

      assert
        .dom("[role='listbox']")
        .doesNotExist("ArrowDown does not open the readonly select");
      assert
        .dom(".d-select__presentation")
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
        .dom(".d-select__chip")
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
          <button class="unlock" type="button" {{on "click" this.unlock}}>
            unlock
          </button>
          <DSelect
            @disabled={{this.locked}}
            @identifier="test-select"
            @items={{ITEMS}}
            @value={{1}}
            @variant="static"
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

module("Integration | ui-kit | DSelect (trigger display)", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    resetOnerror();
  });

  // Form integration hangs on these landing where `role="combobox"` actually is, which differs
  // by variant. Passed as plain attributes they would settle on the wrapper instead, where a
  // `<label for>` resolves to nothing and a description is never announced.
  test("@id, @describedBy and @invalid land on the combobox element", async function (assert) {
    await render(
      <template>
        <div id="hint">Pick your language</div>
        <DSelect
          class="typeahead"
          @describedBy="hint"
          @id="lang"
          @invalid={{true}}
          @items={{ITEMS}}
        />
        <DSelect
          class="static"
          @describedBy="hint"
          @id="lang-static"
          @invalid={{true}}
          @items={{ITEMS}}
          @label="Language"
          @variant="static"
        />
      </template>
    );

    assert
      .dom(".typeahead input[role='combobox']")
      .hasAttribute("id", "lang", "the typeahead carries them on its input")
      .hasAttribute("aria-describedby", "hint")
      .hasAttribute("aria-invalid", "true");
    assert
      .dom(".static[role='combobox']")
      .hasAttribute(
        "id",
        "lang-static",
        "a static trigger carries them on its root"
      )
      .hasAttribute("aria-describedby", "hint")
      .hasAttribute("aria-invalid", "true");
    assert
      .dom(".typeahead.d-select")
      .doesNotHaveAttribute(
        "id",
        "and never on the wrapper, which owns no role"
      );
  });

  // The component describes its own state through the same attribute, so a consumer value has to
  // be merged rather than substituted: whichever side won, the other's description would vanish
  // silently, audible only to someone using a screen reader.
  test("@describedBy is merged with the component's own description", async function (assert) {
    await render(
      <template>
        <div id="hint">Required</div>
        <DSelect
          @describedBy="hint"
          @items={{ITEMS}}
          @multiple={{true}}
          @value={{array 1}}
        />
      </template>
    );

    const described = find("input[role='combobox']").getAttribute(
      "aria-describedby"
    );
    assert.true(
      described.split(" ").length > 1,
      `both descriptions survive: ${described}`
    );
    assert.true(
      described.split(" ").includes("hint"),
      "the consumer's description is present"
    );
  });

  // A bare `disabled` attribute is inert on a div, so without this the control renders fully
  // interactive while reading as configured — the failure is silent in both directions.
  test("a bare disabled attribute fires a debug assertion", async function (assert) {
    let fired = false;
    setupOnerror((error) => {
      fired = true;
      assert.true(
        error.message.includes("`disabled` is an argument, not an attribute"),
        "the assertion names the mistake"
      );
    });

    await render(
      <template><DSelect disabled={{true}} @items={{ITEMS}} /></template>
    );

    assert.true(fired, "the debug assertion fired");
  });

  test("@iconOnly suppresses the label on a static single-select", async function (assert) {
    await render(
      <template>
        <DSelect
          @icon="gear"
          @iconOnly={{true}}
          @items={{ITEMS}}
          @label="Settings"
          @value={{2}}
          @variant="static"
        />
      </template>
    );

    assert
      .dom(".d-select__trigger.--icon-only")
      .exists("the trigger opts into the icon-only layout");
    assert
      .dom(".d-select__leading-icon.d-icon-gear")
      .exists("the leading icon renders");
    assert.dom(".d-select__caret").exists("the caret still renders by default");
    assert
      .dom(".d-select__value")
      .doesNotExist("the selected value text is suppressed");
    assert
      .dom(".d-select__placeholder")
      .doesNotExist("no placeholder text renders either");
  });

  test("@iconOnly also applies to the button variant", async function (assert) {
    await render(
      <template>
        <DSelect
          @icon="gear"
          @iconOnly={{true}}
          @items={{ITEMS}}
          @label="Settings"
          @variant="button"
        />
      </template>
    );

    assert.dom(".d-select__trigger.--icon-only").exists();
    assert.dom(".d-select__leading-icon.d-icon-gear").exists();
    assert.dom(".d-select__value").doesNotExist();
    assert.dom(".d-select__placeholder").doesNotExist();
  });

  test("the icon-only trigger's accessible name comes from @label", async function (assert) {
    await render(
      <template>
        <DSelect
          @icon="gear"
          @iconOnly={{true}}
          @items={{ITEMS}}
          @label="Settings"
          @variant="static"
        />
      </template>
    );

    assert
      .dom("[role='combobox']")
      .hasAttribute(
        "aria-label",
        "Settings",
        "the label-less trigger is named by @label for assistive tech"
      );
  });

  test("@iconOnly is inert on the typeahead variant (editable input keeps its label)", async function (assert) {
    await render(
      <template>
        <DSelect
          @icon="gear"
          @iconOnly={{true}}
          @items={{ITEMS}}
          @label="Fruit"
          @value={{2}}
          @variant="typeahead"
        />
      </template>
    );

    assert
      .dom(".d-select__trigger.--icon-only")
      .doesNotExist("an editable typeahead cannot be icon-only");
    assert
      .dom("[role='combobox']")
      .hasValue("Banana", "the selected value still shows in the input");
  });

  test("@iconOnly is inert on a multi-select (chips are the display)", async function (assert) {
    await render(
      <template>
        <DSelect
          @icon="gear"
          @iconOnly={{true}}
          @items={{ITEMS}}
          @label="Fruits"
          @multiple={{true}}
          @value={{array 2}}
        />
      </template>
    );

    assert
      .dom(".d-select__trigger.--icon-only")
      .doesNotExist("a multi-select shows chips, so it is never icon-only");
    assert
      .dom(".d-select__chip")
      .exists({ count: 1 }, "the selection chip still renders");
  });

  test("a single string @icon still renders one leading icon alongside the label", async function (assert) {
    await render(
      <template>
        <DSelect
          @icon="gear"
          @items={{ITEMS}}
          @label="Fruit"
          @value={{2}}
          @variant="static"
        />
      </template>
    );

    assert
      .dom(".d-select__leading-icon")
      .exists({ count: 1 }, "a scalar @icon renders a single leading icon");
    assert
      .dom(".d-select__value")
      .hasText("Banana", "the label still renders when not icon-only");
  });

  test("@iconOnly without @label is ignored with a warning", async function (assert) {
    const warn = sinon.stub(console, "warn");

    try {
      await render(
        <template>
          <DSelect
            @iconOnly={{true}}
            @items={{ITEMS}}
            @value={{2}}
            @variant="static"
          />
        </template>
      );

      assert
        .dom(".d-select__trigger.--icon-only")
        .doesNotExist("the trigger keeps its text layout");
      assert.dom(".d-select__value").hasText("Banana", "the value shows");
      assert.true(
        warn.calledWithMatch("iconOnly"),
        "a warning names the ignored option"
      );
    } finally {
      warn.restore();
    }
  });

  test("an icon-only dropdown is not constrained to the narrow trigger width", async function (assert) {
    await render(
      <template>
        <DSelect
          @icon="gear"
          @iconOnly={{true}}
          @items={{ITEMS}}
          @label="Pick"
          @variant="static"
        />
      </template>
    );

    const trigger = find(".d-select__trigger.--icon-only");
    await click("[role='combobox']");

    assert
      .dom(".d-select__panel [role='option']")
      .exists("the dropdown renders its options");
    assert.true(
      find(".d-select__panel").offsetWidth > trigger.offsetWidth,
      "the option panel is wider than the compact icon-only trigger, so labels are not clipped"
    );
  });
});

module(
  "Integration | ui-kit | select | DSelect (panel filter naming)",
  function (hooks) {
    setupRenderingTest(hooks);

    // The button variant's trigger is a disclosure, so the in-panel filter is the first thing a
    // reader lands on after opening. Without a name it announces as a bare edit field and the
    // reader is never told what it filters — the placeholder is a last-resort name source that
    // screen readers treat inconsistently.
    test("the in-panel filter input carries the field's accessible name", async function (assert) {
      await render(
        <template>
          <DSelect
            @identifier="test-select"
            @items={{ITEMS}}
            @label="Category"
            @variant="button"
          />
        </template>
      );
      await click(".d-select__trigger");

      assert
        .dom("input.d-select__filter")
        .hasAttribute(
          "aria-label",
          "Category",
          "the filter names the field it narrows"
        );
    });
  }
);

module(
  "Integration | ui-kit | select | DSelect (control trigger naming)",
  function (hooks) {
    setupRenderingTest(hooks);

    // An author-supplied name REPLACES name-from-contents on `role="button"`/`role="combobox"`,
    // so labelling the trigger with the field name alone made the chosen value unspeakable: a
    // category picker holding "Banana" announced only "Category, button".
    test("a control trigger announces the field and its current value", async function (assert) {
      await render(
        <template>
          <DSelect
            @identifier="test-select"
            @items={{ITEMS}}
            @label="Category"
            @value={{2}}
            @variant="static"
          />
        </template>
      );

      assert
        .dom(".d-select__trigger")
        .hasAttribute(
          "aria-label",
          "Category, Banana",
          "the name carries both the field and the held value"
        );
    });

    test("a control trigger with no value announces just the field", async function (assert) {
      await render(
        <template>
          <DSelect
            @identifier="test-select"
            @items={{ITEMS}}
            @label="Category"
            @variant="static"
          />
        </template>
      );

      assert
        .dom(".d-select__trigger")
        .hasAttribute(
          "aria-label",
          "Category",
          "an empty select names only the field"
        );
    });
  }
);

module(
  "Integration | ui-kit | select | DSelect (keyboard clear parity)",
  function (hooks) {
    setupRenderingTest(hooks);

    // select-kit clears on Backspace-with-an-empty-filter unconditionally
    // (select-kit-filter.gjs), and DSelect's own multi path already matches it. Gating only the
    // single path behind @clearable left a picker a reader could reach a value in but not leave.
    test("Backspace on an empty query clears a single selection without @clearable", async function (assert) {
      await render(<template><Host @value={{2}} /></template>);

      await click("[role='combobox']");
      await fillIn("[role='combobox']", "");
      await triggerKeyEvent("[role='combobox']", "keydown", "Backspace");

      assert
        .dom("[role='listbox']")
        .exists("the list is still open after clearing");
      assert
        .dom("[role='option'][aria-selected='true']")
        .doesNotExist("the held value is gone, matching select-kit's gesture");
    });

    test("Backspace with text still in the query only edits the query", async function (assert) {
      await render(<template><Host @value={{2}} /></template>);

      await click("[role='combobox']");
      await fillIn("[role='combobox']", "Ban");
      await triggerKeyEvent("[role='combobox']", "keydown", "Backspace");

      assert
        .dom("[role='option'][aria-selected='true']")
        .exists("a non-empty query means Backspace is ordinary text editing");
    });

    // The typeahead merges the value display and the query into ONE field, so unlike select-kit
    // (whose filter is a separate, always-empty input) the query is not empty while a value is
    // shown. Clearing is therefore a two-step gesture: empty the field, then Backspace.
    test("the typeahead input holds the label, so clearing takes emptying it first", async function (assert) {
      await render(<template><Host @value={{2}} /></template>);
      await click("[role='combobox']");

      assert
        .dom("[role='combobox']")
        .hasValue(
          "Banana",
          "the input shows the held value, not an empty query"
        );

      await triggerKeyEvent("[role='combobox']", "keydown", "Backspace");
      assert
        .dom("[role='option'][aria-selected='true']")
        .exists("a Backspace aimed at the label text is ordinary editing");

      await fillIn("[role='combobox']", "");
      await triggerKeyEvent("[role='combobox']", "keydown", "Backspace");
      assert
        .dom("[role='option'][aria-selected='true']")
        .doesNotExist("once the query is empty, Backspace clears the value");
    });
  }
);

module(
  "Integration | ui-kit | select | DSelect (control variant keyboard clear)",
  function (hooks) {
    setupRenderingTest(hooks);

    // The control variants have no text input, so the closed trigger IS the empty-query state.
    // Gating their Backspace behind @clearable left a static select with no way out at all —
    // not even the two-step gesture the typeahead offers.
    test("Backspace on a closed static trigger clears the value without @clearable", async function (assert) {
      await render(
        <template><Host @value={{2}} @variant="static" /></template>
      );

      await focus(".d-select__trigger");
      await triggerKeyEvent(".d-select__trigger", "keydown", "Backspace");

      assert
        .dom(".d-select__placeholder")
        .exists("the trigger falls back to its placeholder once cleared");
    });

    test("Delete on a closed button trigger clears the value without @clearable", async function (assert) {
      await render(
        <template><Host @value={{2}} @variant="button" /></template>
      );

      await focus(".d-select__trigger");
      await triggerKeyEvent(".d-select__trigger", "keydown", "Delete");

      assert
        .dom(".d-select__placeholder")
        .exists("the same gesture works on the disclosure trigger");
    });

    // Clearing a single select has no other signal: the row leaves the list's selected state and
    // the trigger's accessible name changes, neither of which a reader is reliably told about.
    test("clearing a single selection is announced", async function (assert) {
      const announce = sinon.spy(
        getOwner(this).lookup("service:a11y"),
        "announce"
      );

      await render(
        <template><Host @value={{2}} @variant="static" /></template>
      );

      await focus(".d-select__trigger");
      await triggerKeyEvent(".d-select__trigger", "keydown", "Backspace");

      assert.strictEqual(
        announce.withArgs(i18n("d_select.selection_cleared"), "polite")
          .callCount,
        1,
        "the reader is told the value is gone"
      );
    });
  }
);

/** Controlled selection with asynchronous and variant inputs for strip coverage. */
class SupplementalStripHost extends Component {
  @tracked value = this.args.value ?? [];

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @clearable={{true}}
      @items={{@items}}
      @label="Fruit"
      @maximum={{@maximum}}
      @multiple={{true}}
      @onChange={{this.onChange}}
      @resolveValues={{@resolveValues}}
      @value={{this.value}}
      @variant={{@variant}}
    />
  </template>
}

module(
  "Integration | ui-kit | select | DSelect (selection strip details)",
  function (hooks) {
    setupRenderingTest(hooks);

    for (const key of ["Enter", " "]) {
      test(`${key === " " ? "Space" : key} removes once and focuses the input`, async function (assert) {
        forceMobile();
        await render(
          <template>
            <SupplementalStripHost @items={{ITEMS}} @value={{array 1 2 3}} />
          </template>
        );
        await click(".d-select__trigger");
        const buttons = findAll(".d-select__panel .d-select__chip-remove");
        buttons[2].focus();
        await triggerKeyEvent(buttons[2], "keydown", key);
        await click(buttons[2]);
        assert
          .dom(".d-select__panel .d-select__chip-remove")
          .exists({ count: 2 }, "one item was removed");
        assert.strictEqual(
          document.activeElement,
          find(".d-select__filter"),
          "activation returns to the input"
        );
      });
    }

    test("pointer removal keeps query focus", async function (assert) {
      forceMobile();
      await render(
        <template>
          <SupplementalStripHost @items={{ITEMS}} @value={{array 1 2}} />
        </template>
      );
      await click(".d-select__trigger");
      const input = find(".fk-d-menu-modal .d-select__filter");
      input.focus();
      await click(".d-select__panel .d-select__chip-remove");
      assert.strictEqual(
        document.activeElement,
        input,
        "the keyboard's input keeps focus"
      );
      assert
        .dom(".d-select__panel .d-select__chip-remove")
        .exists({ count: 1 }, "the pointer removed the item");
    });

    for (const closeFirst of [false, true]) {
      test(`desktop blur preserves outside focus after ${closeFirst ? "Escape" : "opening"}`, async function (assert) {
        await render(
          <template>
            <Host @value={{1}} /><button
              class="outside"
              type="button"
            >Outside</button>
          </template>
        );
        await fillIn("[role='combobox']", "ban");
        if (closeFirst) {
          await triggerKeyEvent("[role='combobox']", "keydown", "Escape");
        }
        await focus(".outside");
        assert.strictEqual(
          document.activeElement,
          find(".outside"),
          "closing on blur cannot reclaim focus"
        );
        assert
          .dom(".d-select__presentation")
          .hasText(
            "Apple",
            "the unfocused field restores its selection markup"
          );
        assert.dom("[role='listbox']").doesNotExist("the menu is closed");
      });
    }

    test("Escape preserves focus already on a persistent trigger chip", async function (assert) {
      await render(
        <template>
          <SupplementalStripHost @items={{ITEMS}} @value={{array 1 2 3}} />
        </template>
      );
      await click(".d-select__trigger");
      const input = find("[role='combobox']");
      input.setSelectionRange(0, 0);
      await triggerKeyEvent(input, "keydown", "ArrowLeft");
      const chip = document.activeElement;
      assert
        .dom(chip)
        .hasClass("d-select__chip-remove", "focus entered the trigger chips");
      await triggerKeyEvent(chip, "keydown", "Escape");
      assert.dom("[role='listbox']").doesNotExist("Escape closes the menu");
      assert.strictEqual(
        document.activeElement,
        chip,
        "a surviving focused trigger chip retains focus"
      );
    });

    test("button clear after close focuses its connected trigger", async function (assert) {
      await render(
        <template>
          <SupplementalStripHost
            @items={{ITEMS}}
            @value={{array 1}}
            @variant="button"
          />
        </template>
      );
      await click(".d-select__trigger");
      await triggerKeyEvent(".d-select__filter", "keydown", "Escape");
      await click(".d-select__clear");
      assert.strictEqual(
        document.activeElement,
        find(".d-select__trigger"),
        "clear cannot focus the detached panel input"
      );
    });

    for (const variant of ["typeahead", "static"]) {
      test(`desktop ${variant} keeps its controller after close`, async function (assert) {
        await render(
          <template>
            <SupplementalStripHost
              @items={{ITEMS}}
              @value={{array 1}}
              @variant={{variant}}
            />
          </template>
        );
        await click(".d-select__trigger");
        await triggerKeyEvent("[role='combobox']", "keydown", "Escape");
        await click(".d-select__clear");
        assert.strictEqual(
          document.activeElement,
          find("[role='combobox']"),
          "the persistent controller still receives focus"
        );
        await click(".d-select__trigger");
        await triggerKeyEvent("[role='combobox']", "keydown", "ArrowDown");
        assert
          .dom("[role='combobox']")
          .hasAttribute(
            "aria-activedescendant",
            /.+/,
            "the controller still drives list navigation"
          );
        assert
          .dom(".d-select__strip")
          .doesNotExist("a local desktop list needs no strip");
      });
    }

    test("button modal orders its field, limit and results", async function (assert) {
      forceMobile();
      await render(
        <template>
          <SupplementalStripHost
            @items={{ITEMS}}
            @maximum={{1}}
            @value={{array 1}}
            @variant="button"
          />
        </template>
      );
      await click(".d-select__trigger");
      const panel = find(".fk-d-menu-modal .d-select__panel");
      assert.true(
        Boolean(panel.children[0].querySelector(".d-select__filter")),
        "the query is first"
      );
      assert.true(
        panel.children[1].matches(".d-select__limit"),
        "then the limit"
      );
      assert.true(
        Boolean(panel.children[0].querySelector(".d-select__chip-list")),
        "the field contains the held chips"
      );
      assert.true(
        Boolean(panel.children[2].querySelector("[role='listbox']")),
        "then the list"
      );
    });

    test("an empty static result set retains modal focus after the last removal", async function (assert) {
      forceMobile();
      await render(
        <template>
          <SupplementalStripHost
            @items={{array}}
            @value={{array 99}}
            @variant="static"
          />
        </template>
      );
      await click(".d-select__trigger");
      find(".d-select__strip button").focus();
      await triggerKeyEvent(".d-select__strip button", "keydown", "Delete");
      assert
        .dom(".d-select__strip")
        .doesNotExist("the final unresolved item was removed");
      assert.true(
        Boolean(document.activeElement.closest(".fk-d-menu-modal")),
        "focus stays in the modal even without an option"
      );
    });

    test("touch removal names omit the keyboard hint", async function (assert) {
      forceMobile();
      sinon
        .stub(this.owner.lookup("service:capabilities"), "touch")
        .get(() => true);
      await render(
        <template>
          <SupplementalStripHost @items={{ITEMS}} @value={{array 1}} />
        </template>
      );
      await click(".d-select__trigger");
      assert
        .dom(".d-select__panel .d-select__chip-remove")
        .hasAttribute(
          "aria-label",
          "Remove Apple",
          "touch users hear the item action"
        );
      assert
        .dom(".d-select__panel .d-select__chip-remove")
        .doesNotHaveAttribute(
          "aria-labelledby",
          "the keyboard hint does not override the touch name"
        );
    });

    test("long fields scroll within the panel budget and keep mobile tap targets", async function (assert) {
      forceMobile();
      const items = Array.from({ length: 40 }, (_, id) => ({
        id,
        name: `Held item ${id}`,
      }));
      const value = items.map((item) => item.id);
      await render(
        <template>
          <SupplementalStripHost @items={{items}} @value={{value}} />
        </template>
      );
      await click(".d-select__trigger");
      const strip = find(".d-select__panel .d-select__chips");
      const panel = find(".fk-d-menu-modal .d-select__panel");
      const button = find(".d-select__panel .d-select__chip-remove");
      assert.true(
        strip.scrollHeight > strip.clientHeight,
        "the strip overflows its own viewport"
      );
      assert.strictEqual(
        getComputedStyle(strip).overflowY,
        "auto",
        "the strip owns its scroll"
      );
      assert.true(
        button.offsetHeight >= 44,
        "tap target is at least 44px high"
      );
      assert.true(button.offsetWidth >= 44, "tap target is at least 44px wide");
      assert.true(
        panel.offsetHeight <= parseFloat(getComputedStyle(panel).maxHeight) + 1,
        "input, strip and list fit the panel budget"
      );
    });

    test("chip focus suppresses the active option's second indicator", async function (assert) {
      forceMobile();
      await render(
        <template>
          <SupplementalStripHost @items={{ITEMS}} @value={{array 1}} />
        </template>
      );
      await click(".d-select__trigger");
      const option = find(".d-select__option.--active");
      assert.true(Boolean(option), "the query has an active result");
      find(".d-select__panel .d-select__chip-remove").focus();
      assert.strictEqual(
        getComputedStyle(option).outlineStyle,
        "none",
        "only the strip shows the focus indicator"
      );
      await settled();
      assert
        .dom(".d-select__option.--active")
        .doesNotExist("no row stays active while a chip has focus");
      find(".fk-d-menu-modal .d-select__filter").focus();
      await triggerKeyEvent(".d-select__filter", "keydown", "ArrowDown");
      assert.notStrictEqual(
        getComputedStyle(find(".d-select__option.--active")).outlineStyle,
        "none",
        "the result indicator returns with query navigation"
      );
    });

    test("pending field items have no buttons and unresolved items remain removable", async function (assert) {
      forceMobile();
      let resolve;
      const response = new Promise((done) => (resolve = done));
      const resolveValues = () => response;
      const rendering = render(
        <template>
          <SupplementalStripHost
            @items={{array}}
            @resolveValues={{resolveValues}}
            @value={{array 99 100}}
          />
        </template>
      );
      try {
        await waitFor(".d-select__trigger");
        const opening = click(".d-select__trigger");
        await waitFor(".d-select__panel .d-select__chips .d-skeleton");
        assert
          .dom(".d-select__panel .d-select__chip")
          .exists({ count: 2 }, "one skeleton per held value");
        assert
          .dom(".d-select__panel .d-select__chip-remove")
          .doesNotExist("pending labels cannot be removed");
        resolve([]);
        await rendering;
        await opening;
        await settled();
        assert
          .dom(".d-select__panel .d-select__chips .d-select__unresolved")
          .exists({ count: 2 }, "missing values get fallback labels");
        findAll(".d-select__panel .d-select__chip-remove")[1].focus();
        await triggerKeyEvent(document.activeElement, "keydown", "Delete");
        assert
          .dom(".d-select__panel .d-select__chip-remove")
          .exists({ count: 1 }, "unresolved values can be removed");
        assert
          .dom(document.activeElement.closest("li"))
          .hasAttribute(
            "data-value",
            "99",
            "focus stays on the remaining unresolved item"
          );
      } finally {
        resolve([]);
        await rendering;
      }
    });
  }
);

/** An element's accessible name from aria-labelledby, aria-label or its text. */
function nameOf(element) {
  const ids = element?.getAttribute("aria-labelledby");
  if (ids) {
    return ids
      .split(/\s+/)
      .map((id) => document.getElementById(id)?.textContent.trim() ?? "")
      .join(" ")
      .trim();
  }
  return (
    element?.getAttribute("aria-label") ??
    element?.textContent ??
    ""
  ).trim();
}

/** The text of every element an element's aria-describedby points at. */
function descriptionOf(element) {
  return (element?.getAttribute("aria-describedby") ?? "")
    .split(/\s+/)
    .filter(Boolean)
    .map((id) => document.getElementById(id)?.textContent.trim() ?? "")
    .join(" ");
}

const serverLoad = () => ITEMS;
const serverResolve = (values) =>
  ITEMS.filter((item) => values.includes(item.id));

/** A controlled multi host for compact and overflow tests. */
class CompactHost extends Component {
  @tracked value = this.args.value ?? [];

  get items() {
    return this.args.server ? undefined : ITEMS;
  }

  get load() {
    return this.args.server ? serverLoad : undefined;
  }

  get resolveValues() {
    return this.args.server ? serverResolve : undefined;
  }

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @items={{this.items}}
      @label="Fruit"
      @load={{this.load}}
      @maxVisibleChips={{@maxVisibleChips}}
      @multiple={{true}}
      @onChange={{this.onChange}}
      @resolveValues={{this.resolveValues}}
      @value={{this.value}}
      @variant={{@variant}}
    />
  </template>
}

const TRIGGER = ".d-select__trigger";

module(
  "Integration | ui-kit | select | DSelect (display-only chips)",
  function (hooks) {
    setupRenderingTest(hooks);

    for (const variant of ["button", "static"]) {
      test(`a ${variant} trigger's chips are display-only and readable`, async function (assert) {
        await render(
          <template>
            <CompactHost @value={{array 1 2}} @variant={{variant}} />
          </template>
        );

        assert.dom(`${TRIGGER} .d-select__chip`).exists({ count: 2 });
        assert
          .dom(`${TRIGGER} button.d-select__chip-remove`)
          .doesNotExist("no remove buttons nested in the trigger");
        const described = descriptionOf(find(".d-select"));
        assert.true(
          described.includes("Apple"),
          `describes Apple: ${described}`
        );
        assert.true(described.includes("Banana"), "and Banana");
      });
    }

    test("a mobile trigger's chips are display-only", async function (assert) {
      forceMobile();
      await render(<template><CompactHost @value={{array 1 2}} /></template>);

      assert.dom(`${TRIGGER} .d-select__chip`).exists({ count: 2 });
      assert.dom(`${TRIGGER} button.d-select__chip-remove`).doesNotExist();
    });

    test("a desktop typeahead without a cap keeps removable chips", async function (assert) {
      await render(<template><CompactHost @value={{array 1 2}} /></template>);

      assert
        .dom(`${TRIGGER} button.d-select__chip-remove`)
        .exists({ count: 2 }, "nothing changes without @maxVisibleChips");
    });

    test("a server-backed button panel lists held items in the field", async function (assert) {
      await render(
        <template>
          <CompactHost
            @server={{true}}
            @value={{array 1 2}}
            @variant="button"
          />
        </template>
      );
      await click(TRIGGER);

      assert
        .dom(".d-select__panel .d-select__chip-remove")
        .exists({ count: 2 });
    });

    test("a local button list needs no strip", async function (assert) {
      await render(
        <template>
          <CompactHost @value={{array 1 2}} @variant="button" />
        </template>
      );
      await click(TRIGGER);

      assert
        .dom(".d-select__panel .d-select__chip-remove")
        .exists({ count: 2 }, "the field holds the selected items");
      assert.dom("[role='option'][aria-selected='true']").exists({ count: 2 });
    });

    test("picking the first item shows a field chip without reopening", async function (assert) {
      await render(
        <template><CompactHost @server={{true}} @variant="button" /></template>
      );
      await click(TRIGGER);
      assert.dom(".d-select__panel .d-select__chip").doesNotExist();

      await click(optionWithText("Apple"));
      assert
        .dom(".d-select__panel .d-select__chip-remove")
        .exists({ count: 1 });
    });
  }
);

/** A batch resolver that answers after `ms`, honours its abort signal, and counts its calls. */
function delayedResolver(ms) {
  const calls = [];
  const resolveValues = (values, { signal } = {}) => {
    calls.push(values);
    return new Promise((resolve, reject) => {
      const timer = setTimeout(
        () => resolve(ITEMS.filter((item) => values.includes(item.id))),
        ms
      );
      signal?.addEventListener("abort", () => {
        clearTimeout(timer);
        reject(signal.reason);
      });
    });
  };
  return { calls, resolveValues };
}

const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/** A controlled server-backed multi whose held ids resolve through `@resolver`. */
class ResolvingHost extends Component {
  @tracked value = this.args.value ?? [];

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @label="Fruit"
      @load={{serverLoad}}
      @maxVisibleChips={{@maxVisibleChips}}
      @multiple={{true}}
      @onChange={{this.onChange}}
      @resolveValues={{@resolver.resolveValues}}
      @value={{this.value}}
      @variant={{@variant}}
    />
  </template>
}

module(
  "Integration | ui-kit | select | DSelect (held-label resolution)",
  function (hooks) {
    setupRenderingTest(hooks);

    for (const surface of ["mobile", "button"]) {
      test(`held-label resolution: a ${surface} trigger resolves its held ids once`, async function (assert) {
        if (surface === "mobile") {
          forceMobile();
        }
        const resolver = delayedResolver(30);
        const variant = surface === "button" ? "button" : undefined;

        await render(
          <template>
            <ResolvingHost
              @resolver={{resolver}}
              @value={{array 1 2 999}}
              @variant={{variant}}
            />
          </template>
        );
        await wait(150);
        await settled();

        assert.deepEqual(
          findAll(`${TRIGGER} .d-select__chip`).map((chip) =>
            chip.textContent.trim()
          ),
          ["Apple", "Banana", "Unknown item (999)"],
          "real ids show their items; only the missing id falls back"
        );
        assert.strictEqual(
          resolver.calls.length,
          1,
          `@resolveValues is called once: ${JSON.stringify(resolver.calls)}`
        );
        const described = descriptionOf(find(".d-select"));
        for (const label of ["Apple", "Banana", "Unknown item (999)"]) {
          assert.true(
            described.includes(label),
            `the description names ${label}: ${described}`
          );
        }
      });
    }

    test("held-label resolution: a capped trigger describes every held item from one call", async function (assert) {
      const resolver = delayedResolver(30);

      await render(
        <template>
          <ResolvingHost
            @maxVisibleChips={{1}}
            @resolver={{resolver}}
            @value={{array 1 2 3}}
            @variant="button"
          />
        </template>
      );
      await wait(150);
      await settled();

      assert.dom(`${TRIGGER} .d-select__chip`).exists({ count: 1 });
      const described = descriptionOf(find(".d-select"));
      for (const label of ["Apple", "Banana", "Cherry pie"]) {
        assert.true(
          described.includes(label),
          `the description names ${label} past the cap: ${described}`
        );
      }
      assert.strictEqual(resolver.calls.length, 1, "one call");
    });

    test("held-label resolution: opening the panel while chips resolve adds no request", async function (assert) {
      const resolver = delayedResolver(200);

      const rendering = render(
        <template>
          <ResolvingHost
            @resolver={{resolver}}
            @value={{array 1 2}}
            @variant="button"
          />
        </template>
      );
      await waitFor(TRIGGER);
      const opening = click(TRIGGER);
      await waitFor(".d-select__panel .d-select__chips");
      await Promise.all([rendering, opening]);
      await wait(300);
      await settled();

      assert.strictEqual(
        resolver.calls.length,
        1,
        `one request for the chips, description and panel: ${JSON.stringify(resolver.calls)}`
      );
      assert
        .dom(".d-select__panel .d-select__chip-remove")
        .exists({ count: 2 });
      assert.deepEqual(
        findAll(`${TRIGGER} .d-select__chip`).map((chip) =>
          chip.textContent.trim()
        ),
        ["Apple", "Banana"],
        "the trigger chips resolve to the real items"
      );
    });
  }
);

module(
  "Integration | ui-kit | select | DSelect (panel field)",
  function (hooks) {
    setupRenderingTest(hooks);

    const PANEL = ".d-select__content";
    const panelInput = () =>
      find(`${PANEL} .d-select__chips input[type="search"]`);
    const panelChips = () =>
      findAll(`${PANEL} .d-select__chips .d-select__chip`);
    const panelChipButtons = () =>
      findAll(`${PANEL} .d-select__chips .d-select__chip-remove`);

    test("panel field: a button popup holds its chips in the focused search field", async function (assert) {
      const resolver = delayedResolver(0);
      await render(
        <template>
          <ResolvingHost
            @resolver={{resolver}}
            @value={{array 1 2}}
            @variant="button"
          />
        </template>
      );
      await click(TRIGGER);

      assert
        .dom(`${PANEL} .d-select__strip`)
        .doesNotExist("no strip in the popup");
      assert.deepEqual(
        panelChips().map((chip) => chip.dataset.name),
        ["Apple", "Banana"]
      );
      assert.strictEqual(
        document.activeElement,
        panelInput(),
        "opening focuses the search field"
      );
      assert
        .dom(panelInput())
        .doesNotHaveAttribute(
          "role",
          "the open panel's input is a search field"
        )
        .hasAria("autocomplete", "list");

      await triggerKeyEvent(panelInput(), "keydown", "ArrowLeft");
      assert.strictEqual(
        document.activeElement,
        panelChipButtons()[1],
        "ArrowLeft enters the chips"
      );
      await triggerKeyEvent(document.activeElement, "keydown", "Delete");
      assert.deepEqual(
        panelChips().map((chip) => chip.dataset.name),
        ["Apple"],
        "Delete removes the focused chip"
      );

      await focus(panelInput());
      await triggerKeyEvent(panelInput(), "keydown", "Backspace");
      assert.strictEqual(panelChips().length, 0, "Backspace removes the last");
      assert.dom(PANEL).exists("the popup stays open");
    });

    test("panel field: a button popup's search drives the active descendant on desktop", async function (assert) {
      const resolver = delayedResolver(0);
      await render(
        <template>
          <ResolvingHost
            @resolver={{resolver}}
            @value={{array 1}}
            @variant="button"
          />
        </template>
      );
      find(TRIGGER).dispatchEvent(
        new MouseEvent("click", { bubbles: true, cancelable: true, detail: 0 })
      );
      await settled();
      await fillIn(panelInput(), "an");
      await triggerKeyEvent(panelInput(), "keydown", "ArrowDown");

      const active = find(`${PANEL} [role='option'].--active`);
      assert.dom(active).exists("typing activates a row");
      assert.dom(panelInput()).hasAria("activedescendant", active.id);
    });

    test("panel field: a button popup opened by a touch screen reader drives no active descendant", async function (assert) {
      sinon.stub(capabilities, "isIOS").value(true);
      const resolver = delayedResolver(0);
      await render(
        <template>
          <ResolvingHost
            @resolver={{resolver}}
            @value={{array 1}}
            @variant="button"
          />
        </template>
      );
      find(TRIGGER).dispatchEvent(
        new MouseEvent("click", { bubbles: true, cancelable: true, detail: 0 })
      );
      await settled();
      await fillIn(panelInput(), "an");
      await triggerKeyEvent(panelInput(), "keydown", "ArrowDown");

      assert.dom(`${PANEL} [role='option']`).exists("results render");
      assert
        .dom(panelInput())
        .doesNotHaveAria("activedescendant", "the reader walks the results");
    });

    test("panel field: Escape still closes the button popup", async function (assert) {
      const resolver = delayedResolver(0);
      await render(
        <template>
          <ResolvingHost
            @resolver={{resolver}}
            @value={{array 1}}
            @variant="button"
          />
        </template>
      );
      await click(TRIGGER);

      await triggerKeyEvent(panelInput(), "keydown", "Escape");

      assert.dom(PANEL).doesNotExist("Escape closes the popup");
    });

    test("panel field: the mobile modal holds its chips in the search field", async function (assert) {
      forceMobile();
      const resolver = delayedResolver(0);
      await render(
        <template>
          <ResolvingHost @resolver={{resolver}} @value={{array 1 2}} />
        </template>
      );
      await click(".d-select");

      const field = ".d-modal .d-select__chips";
      assert
        .dom(".d-modal .d-select__strip")
        .doesNotExist("no strip in the modal");
      assert.deepEqual(
        findAll(`${field} .d-select__chip`).map((chip) => chip.dataset.name),
        ["Apple", "Banana"]
      );
      assert
        .dom(`${field} input[type="search"]`)
        .exists("the modal's input is a search field beside the chips")
        .doesNotHaveAttribute("role");
    });

    test("panel field: a single button popup clears its value with Backspace", async function (assert) {
      await render(
        <template><FrameHost @value={{1}} @variant="button" /></template>
      );
      assert.dom(TRIGGER).includesText("Apple", "the value shows at rest");
      await click(TRIGGER);
      const field = find(`${PANEL} input[type="search"]`);
      assert.strictEqual(
        document.activeElement,
        field,
        "the search is focused"
      );
      assert.dom(field).doesNotHaveAttribute("role");

      await triggerKeyEvent(field, "keydown", "Backspace");
      assert
        .dom(TRIGGER)
        .doesNotIncludeText("Apple", "Backspace clears the single value");
    });
  }
);

module(
  "Integration | ui-kit | select | DSelect (compact and overflow)",
  function (hooks) {
    setupRenderingTest(hooks);

    test("compact mode shows a count and names it", async function (assert) {
      await render(
        <template>
          <CompactHost
            @maxVisibleChips={{0}}
            @value={{array 1 2}}
            @variant="button"
          />
        </template>
      );

      assert.dom(`${TRIGGER} .d-select__chip`).doesNotExist();
      assert
        .dom(".d-select__chips-more")
        .hasText("2")
        .hasAttribute("aria-hidden", "true");
      assert.strictEqual(nameOf(find(".d-select")), "Fruit, 2 selected");
    });

    test("overflow shows N chips and the rest as +K", async function (assert) {
      await render(
        <template>
          <CompactHost
            @maxVisibleChips={{1}}
            @value={{array 1 2 3}}
            @variant="button"
          />
        </template>
      );

      assert.dom(`${TRIGGER} .d-select__chip`).exists({ count: 1 });
      assert.dom(`${TRIGGER} .d-select__chip`).hasText("Apple");
      assert.dom(".d-select__chips-more").hasText("+2");
      assert.strictEqual(nameOf(find(".d-select")), "Fruit, 3 selected");
    });

    test("overflow on a local button list relies on the checked list", async function (assert) {
      await render(
        <template>
          <CompactHost
            @maxVisibleChips={{1}}
            @value={{array 1 2 3}}
            @variant="button"
          />
        </template>
      );
      await click(TRIGGER);

      assert
        .dom(".d-select__panel .d-select__chip-remove")
        .exists(
          { count: 3 },
          "the panel shows every held item beyond the trigger cap"
        );
    });

    test("the desktop typeahead compacts and lists held items in its panel", async function (assert) {
      await render(
        <template>
          <CompactHost @maxVisibleChips={{0}} @value={{array 1 2}} />
        </template>
      );

      assert.dom(`${TRIGGER} button.d-select__chip-remove`).doesNotExist();
      assert.strictEqual(
        nameOf(find("[role='combobox']")),
        "Fruit, 2 selected",
        "the input carries the count"
      );
      assert
        .dom(TRIGGER)
        .doesNotIncludeText(
          "Press Left arrow",
          "no hint about chips that are not there"
        );

      await click("[role='combobox']");
      assert.dom(".d-select__strip button").exists({ count: 2 });
    });

    test("ArrowLeft from the compact input reaches the strip", async function (assert) {
      await render(
        <template>
          <CompactHost @maxVisibleChips={{0}} @value={{array 1 2}} />
        </template>
      );
      await focus("[role='combobox']");
      await triggerKeyEvent("[role='combobox']", "keydown", "ArrowLeft");

      assert.dom(".d-select__strip").exists("the panel opens");
      assert.true(
        nameOf(document.activeElement).startsWith("Banana"),
        "focus lands on the last held item"
      );
    });

    test("removing from the strip updates the count", async function (assert) {
      await render(
        <template>
          <CompactHost
            @maxVisibleChips={{0}}
            @server={{true}}
            @value={{array 1 2}}
            @variant="button"
          />
        </template>
      );
      await click(TRIGGER);
      await click(findAll(".d-select__panel .d-select__chip-remove")[0]);

      assert.strictEqual(nameOf(find(".d-select")), "Fruit, 1 selected");
      assert.dom(".d-select__chips-more").hasText("1");
    });

    test("a mobile trigger compacts too", async function (assert) {
      forceMobile();
      await render(
        <template>
          <CompactHost @maxVisibleChips={{0}} @value={{array 1 2}} />
        </template>
      );

      assert.dom(`${TRIGGER} .d-select__chip`).doesNotExist();
      assert.dom(".d-select__chips-more").hasText("2");
      assert.strictEqual(nameOf(find(".d-select")), "Fruit, 2 selected");
    });
  }
);
