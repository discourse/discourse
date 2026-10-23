import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { on } from "@ember/modifier";
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
import sinon from "sinon";
import A11yLiveRegions from "discourse/components/a11y/live-regions";
import { forceMobile } from "discourse/lib/mobile";
import { withPluginApi } from "discourse/lib/plugin-api";
import { disableClearA11yAnnouncementsInTests } from "discourse/services/a11y";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  ITEMS,
  MultiLimitsHost,
  optionWithText,
} from "discourse/tests/helpers/d-select-hosts";
import { setupLegacyBridgeCallbacks } from "discourse/tests/helpers/legacy-bridge-helpers";
import DSelect from "discourse/ui-kit/select/d-select";
import SelectEngine from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

class MultiLimitsStaticHost extends Component {
  @tracked value = this.args.value ?? [];

  @action
  onChange(value, payload) {
    this.args.onChange?.(value, payload);
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="test-multi-limits-static"
      @items={{@items}}
      @maximum={{@maximum}}
      @multiple={{true}}
      @onChange={{this.onChange}}
      @placeholder="Pick some"
      @value={{this.value}}
      @variant="static"
    >
      <:selection as |item|>
        {{~item.name~}}
      </:selection>
      <:item as |item|>
        {{~item.name~}}
      </:item>
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
  lowerMaximum() {
    this.maximum = 2;
  }

  @action
  raiseMaximum() {
    this.maximum = 3;
  }

  <template>
    <DSelect
      @identifier="test-reactive-maximum"
      @items={{@items}}
      @maximum={{this.maximum}}
      @multiple={{true}}
      @onChange={{this.onChange}}
      @value={{this.value}}
      @variant="static"
    >
      <:selection as |item|>
        {{~item.name~}}
      </:selection>
      <:item as |item|>
        {{~item.name~}}
      </:item>
      <:footer>
        <button
          class="raise-maximum"
          type="button"
          {{on "click" this.raiseMaximum}}
        >Raise maximum</button>
        <button
          class="lower-maximum"
          type="button"
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
      @identifier="test-footer-limits"
      @items={{ITEMS}}
      @maximum={{3}}
      @minimum={{2}}
      @multiple={{true}}
      @onChange={{this.onChange}}
      @value={{this.value}}
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
  "Integration | ui-kit | select | DSelect (multi limits)",
  function (hooks) {
    setupRenderingTest(hooks);

    test("pointer activation cannot add an ordinary option at @maximum", async function (assert) {
      const onChange = sinon.spy();
      await render(
        <template>
          <MultiLimitsHost
            @maximum={{2}}
            @onChange={{onChange}}
            @value={{array 1 2}}
          />
        </template>
      );
      await click(".d-select__input");
      await click(optionWithText("Cherry pie"));

      assert.strictEqual(
        onChange.callCount,
        0,
        "the rejected pointer add emits no onChange"
      );
      assert
        .dom(".d-select__chip")
        .exists({ count: 2 }, "the rejected pointer add creates no chip");
    });

    test("Enter cannot add an ordinary option after the value reaches @maximum", async function (assert) {
      const onChange = sinon.spy();
      this.set("value", [1]);

      await render(
        <template>
          <DSelect
            @items={{ITEMS}}
            @maximum={{2}}
            @multiple={{true}}
            @onChange={{onChange}}
            @value={{this.value}}
          />
        </template>
      );
      await click(".d-select__input");
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
            @items={{ITEMS}}
            @maximum={{2}}
            @multiple={{true}}
            @onChange={{onChange}}
            @value={{this.value}}
            @variant="static"
          />
        </template>
      );
      await click(".d-select__trigger");
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
        name: filter,
        __create: true,
      });
      await render(
        <template>
          <MultiLimitsHost
            @allowCreate={{true}}
            @createItem={{createItem}}
            @maximum={{1}}
            @onChange={{onChange}}
            @value={{array 1}}
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
            @maximum={{2}}
            @value={{array 1 2}}
          />
        </template>
      );
      await click(".d-select__input");

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
            @maximum={{2}}
            @onChange={{onChange}}
            @value={{array 1 2}}
          />
        </template>
      );
      await click(".d-select__input");
      await click(optionWithText("Run action"));

      assert.true(onSelect.calledOnce, "the action callback runs at the cap");
      const [control] = onSelect.firstCall.args;
      assert.strictEqual(
        typeof control.revealMore,
        "undefined",
        "the row gets the control handle, not the engine"
      );
      control.select(ITEMS[2]);
      assert.strictEqual(
        onChange.callCount,
        0,
        "selecting through the control is still refused at the cap"
      );
      assert.strictEqual(
        onChange.callCount,
        0,
        "running the action emits no value change"
      );
      assert
        .dom(".d-select__chip")
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
            @maximum={{3}}
            @onChange={{onChange}}
            @value={{array 1 2 3 4 5}}
          />
        </template>
      );

      assert
        .dom(".d-select__chip")
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
            @maximum={{3}}
            @onChange={{onChange}}
            @value={{array 1 2 3 4 5}}
          />
        </template>
      );
      await click(".d-select__input");
      await click(optionWithText("Apple"));

      assert.deepEqual(
        onChange.firstCall.args[0],
        [2, 3, 4, 5],
        "deselecting one over-maximum option emits the remaining four values"
      );
      assert
        .dom(".d-select__chip")
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
            @maximum={{2}}
            @onChange={{onChange}}
            @value={{array 1 2}}
          />
        </template>
      );
      await click(".d-select__chip .d-select__chip-remove");

      assert.deepEqual(
        onChange.firstCall.args[0],
        [2],
        "the chip remove button emits the value without the removed item"
      );
      assert
        .dom(".d-select__chip")
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
            @maximum={{2}}
            @onChange={{onChange}}
            @value={{array 1 2}}
          />
        </template>
      );
      await triggerKeyEvent(
        ".d-select__chip .d-select__chip-remove",
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
            @maximum={{2}}
            @onChange={{onChange}}
            @value={{array 1 2}}
          />
        </template>
      );
      await triggerKeyEvent(
        ".d-select__chip .d-select__chip-remove",
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
            @maximum={{2}}
            @onChange={{onChange}}
            @value={{array 1 2}}
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
            @clearable={{true}}
            @maximum={{2}}
            @onChange={{onChange}}
            @value={{array 1 2}}
          />
        </template>
      );
      await click(".d-select__clear");

      assert.deepEqual(
        onChange.firstCall.args[0],
        [],
        "clear-all emits an empty multi-select value at the cap"
      );
      assert
        .dom(".d-select__chip")
        .doesNotExist("clear-all removes every chip at the cap");
    });

    test("a null value entry consumes a @maximum slot that removing its chip reclaims", async function (assert) {
      const onChange = sinon.spy();
      await render(
        <template>
          <MultiLimitsHost
            @maximum={{2}}
            @onChange={{onChange}}
            @value={{array null 1}}
          />
        </template>
      );

      // A null still renders its own removable chip, so it occupies a slot like any other held
      // value — counting it is what keeps the visible selection from outgrowing the cap.
      assert
        .dom(".d-select__chip")
        .exists({ count: 2 }, "the null entry renders a chip of its own");

      await click(".d-select__input");
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
      await click(".d-select__chip .d-select__chip-remove");
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
              @maximum={{0}}
              @onChange={{zeroChange}}
              @value={{array 1}}
            />
          </div>
          <div class="negative-maximum">
            <MultiLimitsHost
              @maximum={{-1}}
              @onChange={{negativeChange}}
              @value={{array 1}}
            />
          </div>
        </template>
      );

      await click(".zero-maximum .d-select__input");
      await click(".zero-maximum [role='option'][aria-selected='false']");
      assert.true(
        zeroChange.calledOnce,
        "@maximum={{0}} allows an additional selection"
      );

      await click(".negative-maximum .d-select__input");
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
            @minimum={{3}}
            @onChange={{onChange}}
            @value={{array 1}}
          />
        </template>
      );
      await click(".d-select__input");
      await click("[role='option'][aria-selected='true']");

      assert.deepEqual(
        onChange.firstCall.args[0],
        [],
        "deselecting the last option emits zero selections below minimum"
      );
      assert
        .dom(".d-select__chip")
        .doesNotExist("the final chip is removed below minimum");
    });

    test("clear-all can go below @minimum to zero", async function (assert) {
      const onChange = sinon.spy();
      await render(
        <template>
          <MultiLimitsHost
            @clearable={{true}}
            @minimum={{3}}
            @onChange={{onChange}}
            @value={{array 1 2}}
          />
        </template>
      );
      await click(".d-select__clear");

      assert.deepEqual(
        onChange.firstCall.args[0],
        [],
        "clear-all emits zero selections below minimum"
      );
      assert
        .dom(".d-select__chip")
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
            @maximum={{1}}
            @minimum={{3}}
            @onChange={{this.onChange}}
            @value={{this.value}}
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
    setupLegacyBridgeCallbacks(hooks);

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
            @maximum={{2}}
            @onChange={{onChange}}
            @value={{array 1 2}}
          />
        </template>
      );
      await click(".d-select__input");
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
        .dom(".d-select__chip")
        .exists({ count: 2 }, "the compat bridge cannot add a chip at the cap");
    });
  }
);

module(
  "Integration | ui-kit | select | DSelect (multi limits keyboard)",
  function (hooks) {
    setupRenderingTest(hooks);

    test("typeahead open at @maximum is inert until deliberate navigation", async function (assert) {
      const onChange = sinon.spy();
      await render(
        <template>
          <MultiLimitsHost
            @maximum={{2}}
            @onChange={{onChange}}
            @value={{array 1 2}}
          />
        </template>
      );

      await click(".d-select__input");
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
        .dom(".d-select__chip")
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
        .dom(".d-select__chip")
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
            @maximum={{2}}
            @onChange={{onChange}}
            @value={{array 1 2}}
          />
        </template>
      );

      await click(".d-select__trigger");
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
        .dom(".d-select__chip")
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
        .dom(".d-select__chip")
        .exists(
          { count: 1 },
          "deliberate static navigation followed by Enter removes one chip"
        );
    });

    test("arrow navigation reaches every option at @maximum", async function (assert) {
      const items = [
        ...ITEMS,
        { id: 4, name: "Date" },
        { id: 5, name: "Elderberry" },
      ];
      await render(
        <template>
          <MultiLimitsStaticHost
            @items={{items}}
            @maximum={{3}}
            @value={{array 1 3 5}}
          />
        </template>
      );
      await click(".d-select__trigger");

      const controller = find("[role='combobox']");
      for (const [key, expected, disabled] of [
        ["ArrowDown", "Apple", false],
        ["ArrowDown", "Banana", true],
        ["ArrowDown", "Cherry pie", false],
        ["ArrowUp", "Banana", true],
        ["ArrowUp", "Apple", false],
      ]) {
        await triggerKeyEvent(controller, "keydown", key);
        const active = find("[role='option'].--active");

        assert
          .dom(active)
          .hasText(
            expected,
            `${key} steps to the next option, disabled or not`
          );
        if (disabled) {
          assert
            .dom(active)
            .hasAttribute(
              "aria-disabled",
              "true",
              `${key} lands on a cap-disabled option, announced as unavailable`
            );
        } else {
          assert.dom(active).doesNotHaveAttribute("aria-disabled");
        }
        assert
          .dom(controller)
          .hasAttribute(
            "aria-activedescendant",
            active.id,
            `${key} points the controller at the active option`
          );
      }
    });

    test("jump keys address every option at @maximum", async function (assert) {
      const items = Array.from({ length: 8 }, (_, index) => ({
        id: index + 1,
        name: `Item ${index + 1}`,
      }));
      await render(
        <template>
          <MultiLimitsStaticHost
            @items={{items}}
            @maximum={{2}}
            @value={{array 2 7}}
          />
        </template>
      );
      await click(".d-select__trigger");

      const controller = find("[role='combobox']");
      for (const [key, expected] of [
        ["End", "Item 8"],
        ["Home", "Item 1"],
        ["PageDown", "Item 8"],
        ["PageUp", "Item 1"],
      ]) {
        await triggerKeyEvent(controller, "keydown", key);
        const active = find("[role='option'].--active");

        assert
          .dom(active)
          .hasText(expected, `${key} resolves against the whole option set`);
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
      await click(".d-select__trigger");

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
        .dom("[role='option'].--active")
        .hasText(
          "Banana",
          "lowering the cap keeps the cursor where the reader left it"
        )
        .hasAttribute("aria-disabled", "true", "now announced as unavailable");
    });
  }
);

module(
  "Integration | ui-kit | select | DSelect (multi limits messages)",
  function (hooks) {
    setupRenderingTest(hooks);

    // The case that justifies the service composing same-type announcements in one flush.
    // Adding the item that reaches the cap produces two messages at once, and they are different
    // facts: what was added, and why nothing more can be. Without composition one clobbers the
    // other and the reader hears only half of it. Asserted on the region text rather than on
    // `announce` call counts, because the spy records calls that a single slot may never deliver.
    test("adding the item that reaches the cap announces both the addition and the cap", async function (assert) {
      disableClearA11yAnnouncementsInTests();

      await render(
        <template>
          <A11yLiveRegions />
          <MultiLimitsHost @maximum={{2}} @value={{array 1}} />
        </template>
      );
      await click(".d-select__input");
      await click("[role='option']:not([aria-selected='true'])");

      assert
        .dom("#a11y-announcements-polite")
        .hasText(
          `${i18n("d_select.item_added", { item: "Banana" })}. ${i18n(
            "d_select.max_reached",
            { count: 2 }
          )}`,
          "both facts reach the reader in one announcement"
        );
    });

    test("the maximum limit message renders as a status above the listbox", async function (assert) {
      await render(
        <template>
          <MultiLimitsHost @maximum={{2}} @value={{array 1 2}} />
        </template>
      );
      await click(".d-select__input");

      const panel = find(".d-select__panel");
      const limit = find(".d-select__limit");
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
          <MultiLimitsHost @minimum={{2}} @value={{array 1}} />
        </template>
      );
      await click(".d-select__input");

      assert
        .dom(".d-select__limit")
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
            @maximum={{1}}
            @minimum={{3}}
            @value={{1}}
          />
        </template>
      );
      await click("[role='combobox']");

      assert
        .dom(".d-select__limit")
        .doesNotExist(
          "single-select ignores maximum and minimum message state"
        );
    });

    test("the limit message is suppressed below @minChars", async function (assert) {
      await render(
        <template>
          <DSelect
            @items={{ITEMS}}
            @maximum={{2}}
            @minChars={{3}}
            @multiple={{true}}
            @value={{array 1 2}}
          />
        </template>
      );
      await fillIn("[role='combobox']", "a");

      assert
        .dom(".d-select__limit")
        .doesNotExist(
          "the cap message is hidden while the query is below minChars"
        );
      assert
        .dom(".d-select__min-chars")
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
      await click(".d-select__input");

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

module(
  "Integration | ui-kit | select | DSelect (disabled rows)",
  function (hooks) {
    setupRenderingTest(hooks);

    const REASONED = [
      { id: 1, name: "Apple" },
      {
        id: 2,
        name: "Banana",
        disabled: true,
        description: "Requires the fruit tag",
      },
      { id: 3, name: "Cherry" },
    ];

    test("arrow keys reach a row disabled for a reason", async function (assert) {
      const onChange = sinon.spy();

      await render(
        <template>
          <DSelect
            @items={{REASONED}}
            @onChange={{onChange}}
            @variant="static"
          />
        </template>
      );
      await click(".d-select__trigger");
      await triggerKeyEvent("[role='combobox']", "keydown", "Home");
      await triggerKeyEvent("[role='combobox']", "keydown", "ArrowDown");

      assert
        .dom("[role='option'].--active")
        .hasText(/Banana/, "the disabled row is reachable")
        .hasAttribute("aria-disabled", "true");

      await triggerKeyEvent("[role='combobox']", "keydown", "Enter");
      assert.true(onChange.notCalled, "but it cannot be picked");
    });

    test("a disabled row's reason is its visible description", async function (assert) {
      await render(
        <template><DSelect @items={{REASONED}} @variant="static" /></template>
      );
      await click(".d-select__trigger");

      const banana = findAll("[role='option']").find((row) =>
        row.textContent.includes("Banana")
      );
      const ids = (banana.getAttribute("aria-describedby") ?? "").split(/\s+/);
      const described = ids
        .map((id) => document.getElementById(id)?.textContent.trim())
        .filter(Boolean);
      assert.true(
        described.includes("Requires the fruit tag"),
        "the reason describes the option"
      );
      assert
        .dom(banana)
        .includesText("Requires the fruit tag", "and is visible");
    });

    test("End reaches a disabled last row", async function (assert) {
      const items = [
        { id: 1, name: "Apple" },
        { id: 2, name: "Banana", disabled: true },
      ];

      await render(
        <template><DSelect @items={{items}} @variant="static" /></template>
      );
      await click(".d-select__trigger");
      await triggerKeyEvent("[role='combobox']", "keydown", "End");

      assert.dom("[role='option'].--active").hasText("Banana");
    });

    test("at the cap every row stays reachable and positions never vanish", async function (assert) {
      const items = [
        { id: 1, name: "Apple" },
        { id: 2, name: "Banana" },
        { id: 3, name: "Cherry" },
      ];
      const onChange = sinon.spy();

      await render(
        <template>
          <DSelect
            @items={{items}}
            @maximum={{1}}
            @multiple={{true}}
            @onChange={{onChange}}
            @value={{array 1}}
            @variant="static"
          />
        </template>
      );
      await click(".d-select__trigger");
      await triggerKeyEvent("[role='combobox']", "keydown", "Home");

      const seen = [];
      for (let step = 0; step < 3; step++) {
        seen.push(
          find("[role='option'].--active")?.getAttribute("aria-posinset")
        );
        await triggerKeyEvent("[role='combobox']", "keydown", "ArrowDown");
      }
      assert.deepEqual(
        seen,
        ["1", "2", "3"],
        "every position is visited in order"
      );

      const banana = findAll("[role='option']").find((row) =>
        row.textContent.includes("Banana")
      );
      assert.dom(banana).hasAttribute("aria-disabled", "true");
      const limit = find(".d-select__limit");
      assert.true(
        (banana.getAttribute("aria-describedby") ?? "")
          .split(/\s+/)
          .includes(limit?.id),
        "a cap-disabled row is described by the limit message"
      );

      await click(banana);
      assert.true(
        onChange.notCalled,
        "a cap-disabled row still cannot be picked"
      );
    });
  }
);

/** Dispatches a cancellable native paste without waiting for pending parser work. */
function pasteBulk(text, selector = "input[role='combobox']") {
  const clipboardData = new DataTransfer();
  clipboardData.setData("text/plain", text);
  const event = new ClipboardEvent("paste", {
    clipboardData,
    bubbles: true,
    cancelable: true,
  });
  find(selector).dispatchEvent(event);
  return event;
}

/** Lets each test finish its parser without awaiting settled while it is pending. */
function pendingParse() {
  let resolve;
  const promise = new Promise((done) => (resolve = done));
  return { promise, resolve };
}

module(
  "Integration | ui-kit | select | DSelect (bulk add and paste)",
  function (hooks) {
    setupRenderingTest(hooks);
    hooks.beforeEach(function () {
      this.emptyValue = [];
    });

    test("mobile typeahead consumes a parsed paste with context", async function (assert) {
      forceMobile();
      const onChange = sinon.spy();
      const parsePaste = sinon.spy(() => [ITEMS[0], ITEMS[1]]);
      await render(
        <template>
          <DSelect
            @items={{ITEMS}}
            @multiple={{true}}
            @onChange={{onChange}}
            @parsePaste={{parsePaste}}
            @value={{this.emptyValue}}
          />
        </template>
      );
      await click(".d-select");
      await fillIn("input.d-select__filter", "query");
      const event = pasteBulk("one|two", "input.d-select__filter");
      await settled();
      assert.true(event.defaultPrevented, "mobile paste is consumed");
      assert.strictEqual(onChange.callCount, 1, "the batch emits once");
      const [text, context] = parsePaste.firstCall.args;
      assert.strictEqual(text, "one|two", "the parser receives plain text");
      assert.strictEqual(
        context.filter,
        "query",
        "the parser receives the current query"
      );
      assert.deepEqual(
        context.value,
        [],
        "the parser receives the current value"
      );
      assert.true(
        Boolean(context.options),
        "the parser receives resolved options"
      );
      assert
        .dom("input.d-select__filter")
        .hasValue("", "the mobile query clears");
    });

    test("async parsing preserves newer typing even when the batch still lands", async function (assert) {
      const gate = pendingParse();
      const onChange = sinon.spy();
      const parsePaste = () => gate.promise;
      await render(
        <template>
          <DSelect
            @items={{ITEMS}}
            @multiple={{true}}
            @onChange={{onChange}}
            @parsePaste={{parsePaste}}
            @value={{this.emptyValue}}
          />
        </template>
      );
      await click("input[role='combobox']");
      await fillIn("input[role='combobox']", "old");
      try {
        pasteBulk("one|two");
        const input = find("input[role='combobox']");
        input.value = "new";
        input.dispatchEvent(new Event("input", { bubbles: true }));
      } finally {
        gate.resolve([ITEMS[0], ITEMS[1]]);
        await settled();
      }
      assert.strictEqual(
        onChange.callCount,
        1,
        "typing alone does not revoke selection authority"
      );
      assert
        .dom("input[role='combobox']")
        .hasValue("new", "the parser leaves newer typing intact");
    });

    test("synchronous change middleware can supersede paste cleanup", async function (assert) {
      withPluginApi((api) => {
        api.registerValueTransformer(
          "select-customizations",
          ({ value: selects }) =>
            selects.forAll((spec) =>
              spec.change((next, context) => {
                context.control.clear();
              })
            )
        );
      });
      const onChange = sinon.spy();
      const parsePaste = () => [ITEMS[0]];
      await render(
        <template>
          <DSelect
            @items={{ITEMS}}
            @multiple={{true}}
            @onChange={{onChange}}
            @parsePaste={{parsePaste}}
            @value={{this.emptyValue}}
          />
        </template>
      );
      await click("input[role='combobox']");
      await fillIn("input[role='combobox']", "keep");
      const event = pasteBulk("one|two");
      await settled();
      assert.true(event.defaultPrevented, "the parser consumed the paste");
      assert.strictEqual(onChange.callCount, 0, "middleware vetoes the batch");
      assert
        .dom("input[role='combobox']")
        .hasValue("keep", "the revoked paste cannot clear the query");
    });

    test("bulk feedback combines held and limit reasons and suppresses trailing counts", async function (assert) {
      const a11y = this.owner.lookup("service:a11y");
      const announce = sinon.spy(a11y, "announce");
      const onChange = sinon.spy();
      const parsePaste = () => [ITEMS[0], ITEMS[1], ITEMS[2]];
      await render(
        <template>
          <DSelect
            @items={{ITEMS}}
            @maximum={{2}}
            @multiple={{true}}
            @onChange={{onChange}}
            @parsePaste={{parsePaste}}
            @value={{array 1}}
          />
        </template>
      );
      await click("input[role='combobox']");
      await fillIn("input[role='combobox']", "A");
      announce.resetHistory();
      pasteBulk("one|two|three");
      await settled();
      assert.strictEqual(
        announce.callCount,
        1,
        "only one announcement, including after the query reset"
      );
      const [message, priority] = announce.firstCall.args;
      assert.true(message.includes("1 added"), "the addition count is spoken");
      assert.true(
        message.includes("1 not added: already selected"),
        "the held reason is spoken"
      );
      assert.true(
        message.includes("1 not added: over the limit"),
        "the limit reason is spoken"
      );
      assert.strictEqual(priority, "polite", "bulk feedback is polite");
    });
  }
);

module(
  "Integration | ui-kit | select | DSelect (maximum false)",
  function (hooks) {
    setupRenderingTest(hooks);

    let warnStub;

    hooks.beforeEach(function () {
      warnStub = sinon.stub(console, "warn");
    });

    hooks.afterEach(function () {
      warnStub.restore();
    });

    const capWarnings = () =>
      warnStub
        .getCalls()
        .filter((call) => String(call.args[0]).includes("@maximum={{false}}"));

    test("lets a held selection grow without a cap", async function (assert) {
      const onChange = sinon.spy();
      await render(
        <template>
          <MultiLimitsHost
            @maximum={{false}}
            @onChange={{onChange}}
            @value={{array 1 2}}
          />
        </template>
      );

      await click(".d-select__input");
      await click("[role='option'][aria-selected='false']");
      assert.true(onChange.calledOnce, "a third item is added");
      assert.dom(".d-select__limit").doesNotExist("no limit message is shown");
      assert.strictEqual(capWarnings().length, 0, "false never warns");
    });

    test("a cap of one or more does not warn", async function (assert) {
      await render(
        <template>
          <MultiLimitsHost @maximum={{2}} @value={{array 1}} />
        </template>
      );
      await click(".d-select__input");
      assert.strictEqual(capWarnings().length, 0, "a real cap is silent");
    });

    test("zero and negative caps warn once per select in development", async function (assert) {
      const zeroChange = sinon.spy();
      await render(
        <template>
          <div class="zero-maximum">
            <MultiLimitsHost
              @maximum={{0}}
              @onChange={{zeroChange}}
              @value={{array 1}}
            />
          </div>
          <div class="negative-maximum">
            <MultiLimitsHost @maximum={{-1}} @value={{array 1}} />
          </div>
        </template>
      );

      await click(".zero-maximum .d-select__input");
      await click(".zero-maximum [role='option'][aria-selected='false']");
      await click(".negative-maximum .d-select__input");

      assert.true(
        zeroChange.calledOnce,
        "zero still means no cap, so the addition goes through"
      );
      assert.strictEqual(
        capWarnings().length,
        2,
        "each select warns exactly once, however often its cap is read"
      );
    });
  }
);
