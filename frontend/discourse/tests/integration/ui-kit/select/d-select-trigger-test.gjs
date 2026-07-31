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
  setupOnerror,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { Host, ITEMS } from "discourse/tests/helpers/d-select-hosts";
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
            <FrameHost @clearable={{true}} @variant="button" @value={{1}} />
          </label>
        </template>
      );

      assert.dom(".d-combobox__clear").exists("the clear control is present");
      assert.strictEqual(
        find(".field-label").control,
        find(".d-combobox__label-sink"),
        "the label's control is the sink, not the clear button"
      );

      await click(".field-text");
      assert
        .dom(".d-combobox__value")
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
            <DSelect @items={{ITEMS}} @value={{1}} @identifier="test-footer">
              <:footer>
                <button
                  type="button"
                  class="footer-action"
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
        find(".d-combobox__input"),
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
            <DSelect @items={{ITEMS}} @value={{1}} @identifier="test-caret" />
          </label>
        </template>
      );

      await click(".field-text");
      const input = find(".d-combobox__input");
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
            <FrameHost @variant="button" @value={{1}} />
          </label>
        </template>
      );

      await click(".field-text");
      assert.strictEqual(
        document.activeElement,
        find(".d-combobox__trigger"),
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
        find(".d-combobox").contains(document.activeElement),
        "focus stays outside a locked control"
      );
    });

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
          @items={{ITEMS}}
          @id="lang"
          @describedBy="hint"
          @invalid={{true}}
        />
        <DSelect
          class="static"
          @items={{ITEMS}}
          @variant="static"
          @label="Language"
          @id="lang-static"
          @describedBy="hint"
          @invalid={{true}}
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
      .dom(".typeahead.d-combobox")
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
          @items={{ITEMS}}
          @multiple={{true}}
          @value={{array 1}}
          @describedBy="hint"
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
      <template><DSelect @items={{ITEMS}} disabled={{true}} /></template>
    );

    assert.true(fired, "the debug assertion fired");
  });

  test("@iconOnly suppresses the label on a static single-select", async function (assert) {
    await render(
      <template>
        <DSelect
          @items={{ITEMS}}
          @variant="static"
          @value={{2}}
          @icon="gear"
          @iconOnly={{true}}
          @label="Settings"
        />
      </template>
    );

    assert
      .dom(".d-combobox__trigger.--icon-only")
      .exists("the trigger opts into the icon-only layout");
    assert
      .dom(".d-combobox__leading-icon.d-icon-gear")
      .exists("the leading icon renders");
    assert
      .dom(".d-combobox__caret")
      .exists("the caret still renders by default");
    assert
      .dom(".d-combobox__value")
      .doesNotExist("the selected value text is suppressed");
    assert
      .dom(".d-combobox__placeholder")
      .doesNotExist("no placeholder text renders either");
  });

  test("@iconOnly also applies to the button variant", async function (assert) {
    await render(
      <template>
        <DSelect
          @items={{ITEMS}}
          @variant="button"
          @icon="gear"
          @iconOnly={{true}}
          @label="Settings"
        />
      </template>
    );

    assert.dom(".d-combobox__trigger.--icon-only").exists();
    assert.dom(".d-combobox__leading-icon.d-icon-gear").exists();
    assert.dom(".d-combobox__value").doesNotExist();
    assert.dom(".d-combobox__placeholder").doesNotExist();
  });

  test("the icon-only trigger's accessible name comes from @label", async function (assert) {
    await render(
      <template>
        <DSelect
          @items={{ITEMS}}
          @variant="static"
          @icon="gear"
          @iconOnly={{true}}
          @label="Settings"
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
          @items={{ITEMS}}
          @variant="typeahead"
          @value={{2}}
          @icon="gear"
          @iconOnly={{true}}
          @label="Fruit"
        />
      </template>
    );

    assert
      .dom(".d-combobox__trigger.--icon-only")
      .doesNotExist("an editable typeahead cannot be icon-only");
    assert
      .dom("[role='combobox']")
      .hasValue("Banana", "the selected value still shows in the input");
  });

  test("@iconOnly is inert on a multi-select (chips are the display)", async function (assert) {
    await render(
      <template>
        <DSelect
          @items={{ITEMS}}
          @multiple={{true}}
          @value={{array 2}}
          @icon="gear"
          @iconOnly={{true}}
          @label="Fruits"
        />
      </template>
    );

    assert
      .dom(".d-combobox__trigger.--icon-only")
      .doesNotExist("a multi-select shows chips, so it is never icon-only");
    assert
      .dom(".d-combobox__chip")
      .exists({ count: 1 }, "the selection chip still renders");
  });

  test("a single string @icon still renders one leading icon alongside the label", async function (assert) {
    await render(
      <template>
        <DSelect
          @items={{ITEMS}}
          @variant="static"
          @value={{2}}
          @icon="gear"
          @label="Fruit"
        />
      </template>
    );

    assert
      .dom(".d-combobox__leading-icon")
      .exists({ count: 1 }, "a scalar @icon renders a single leading icon");
    assert
      .dom(".d-combobox__value")
      .hasText("Banana", "the label still renders when not icon-only");
  });

  test("@iconOnly without @label fires a debug assertion", async function (assert) {
    let fired = false;
    setupOnerror((error) => {
      fired = true;
      assert.true(
        error.message.includes("`@iconOnly` requires `@label`"),
        "the assertion names the missing @label requirement"
      );
    });

    await render(
      <template>
        <DSelect @items={{ITEMS}} @variant="static" @iconOnly={{true}} />
      </template>
    );

    assert.true(fired, "the debug assertion fired during render");
  });

  test("an icon-only dropdown is not constrained to the narrow trigger width", async function (assert) {
    await render(
      <template>
        <DSelect
          @items={{ITEMS}}
          @variant="static"
          @icon="gear"
          @iconOnly={{true}}
          @label="Pick"
        />
      </template>
    );

    const trigger = find(".d-combobox__trigger.--icon-only");
    await click("[role='combobox']");

    assert
      .dom(".d-combobox__panel [role='option']")
      .exists("the dropdown renders its options");
    assert.true(
      find(".d-combobox__panel").offsetWidth > trigger.offsetWidth,
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
            @items={{ITEMS}}
            @variant="button"
            @label="Category"
            @identifier="test-select"
          />
        </template>
      );
      await click(".d-combobox__trigger");

      assert
        .dom("input.d-combobox__filter")
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
            @items={{ITEMS}}
            @variant="static"
            @label="Category"
            @value={{2}}
            @identifier="test-select"
          />
        </template>
      );

      assert
        .dom(".d-combobox__trigger")
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
            @items={{ITEMS}}
            @variant="static"
            @label="Category"
            @identifier="test-select"
          />
        </template>
      );

      assert
        .dom(".d-combobox__trigger")
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
        <template><Host @variant="static" @value={{2}} /></template>
      );

      await focus(".d-combobox__trigger");
      await triggerKeyEvent(".d-combobox__trigger", "keydown", "Backspace");

      assert
        .dom(".d-combobox__placeholder")
        .exists("the trigger falls back to its placeholder once cleared");
    });

    test("Delete on a closed button trigger clears the value without @clearable", async function (assert) {
      await render(
        <template><Host @variant="button" @value={{2}} /></template>
      );

      await focus(".d-combobox__trigger");
      await triggerKeyEvent(".d-combobox__trigger", "keydown", "Delete");

      assert
        .dom(".d-combobox__placeholder")
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
        <template><Host @variant="static" @value={{2}} /></template>
      );

      await focus(".d-combobox__trigger");
      await triggerKeyEvent(".d-combobox__trigger", "keydown", "Backspace");

      assert.strictEqual(
        announce.withArgs(i18n("d_select.selection_cleared"), "polite")
          .callCount,
        1,
        "the reader is told the value is gone"
      );
    });
  }
);
