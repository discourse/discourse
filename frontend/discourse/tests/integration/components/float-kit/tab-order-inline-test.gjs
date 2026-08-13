import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import {
  click,
  find,
  focus,
  render,
  setupOnerror,
  tab,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import DMenu from "discourse/float-kit/components/d-menu";
import {
  adjacentTabStop,
  tabStopsWithin,
} from "discourse/float-kit/lib/tab-order";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dElement from "discourse/ui-kit/helpers/d-element";

/**
 * `inlineTabOrder` only means anything when the content is portaled away from its trigger, and
 * float-kit renders floats IN PLACE under tests (`DFloatPortal`, `@inline ?? isTesting()`). So
 * every case here forces the portal on with `@inline={{false}}` and points it at an outlet that
 * sits LAST in the document — reproducing the real arrangement, where the portal's position is
 * not the trigger's, and where native Tab out of the panel would therefore land in the wrong
 * place.
 *
 * Each menu waits on `{{#if this.outlet}}`: the outlet element only exists after its own insert
 * hook runs, and `{{#in-element}}` rejects a nullish destination. The menu still renders in its
 * template position, so DOM order stays trigger → neighbour → portal.
 *
 * The `tab()` helper dispatches a cancelable, bubbling `keydown` and moves focus only when the
 * default is not prevented, so the modifier's handling is exercised rather than bypassed.
 *
 * What it CANNOT exercise is a browser adopting a scroll container as a tab stop: `tab()` picks
 * candidates by `tabIndex >= 0`, and an adopted scroller reports `-1` exactly like one that opted
 * out. A surface using this option must opt such a scroller out explicitly with `tabindex="-1"`.
 */
module(
  "Integration | Modifier | FloatKit | tab-order-inline",
  function (hooks) {
    setupRenderingTest(hooks);

    // Identity by id, so a failure names the element that actually holds focus.
    const activeId = () =>
      document.activeElement?.id ||
      document.activeElement?.className ||
      "<none>";

    hooks.beforeEach(function () {
      this.setOutlet = (element) => this.set("outlet", element);
    });

    test("Tab enters the float's own controls, then leaves for the trigger's neighbour", async function (assert) {
      await render(
        <template>
          {{#if this.outlet}}
            <DMenu
              @inline={{false}}
              @trapTab={{false}}
              @inlineTabOrder={{true}}
              @label="trigger"
              @portalOutletElement={{this.outlet}}
            >
              <:content>
                <button type="button" id="in-panel" class="in-panel">panel
                  action</button>
              </:content>
            </DMenu>
          {{/if}}
          <button
            type="button"
            id="after-trigger"
            class="after-trigger"
          >after</button>
          <div id="outlet" {{didInsert this.setOutlet}}></div>
        </template>
      );

      await click(".fk-d-menu__trigger");
      assert
        .dom("#outlet .in-panel")
        .exists("the panel really is portaled out");

      // Into the panel. Native order would send this to `.after-trigger`, since the outlet sits
      // beyond it in the document.
      await tab();
      assert.strictEqual(
        activeId(),
        "in-panel",
        "Tab from the trigger enters the panel's control"
      );

      // Off the end of the panel's controls: back to the field's place in the page.
      await tab();
      assert.strictEqual(
        activeId(),
        "after-trigger",
        "Tab off the last panel control resumes after the TRIGGER, not after the portal"
      );
      assert
        .dom("#outlet .in-panel")
        .doesNotExist("leaving the panel also dismisses it");
    });

    test("a non-focusable trigger wrapper resumes from its last stop", async function (assert) {
      await render(
        <template>
          {{#if this.outlet}}
            <DMenu
              @inline={{false}}
              @trapTab={{false}}
              @inlineTabOrder={{true}}
              @triggerComponent={{dElement "div"}}
              @portalOutletElement={{this.outlet}}
            >
              <:trigger>
                <input id="trigger-input" aria-label="trigger" />
              </:trigger>
              <:content>
                <button type="button" id="in-panel">panel action</button>
              </:content>
            </DMenu>
          {{/if}}
          <button type="button" id="after-trigger">after</button>
          <div id="outlet" {{didInsert this.setOutlet}}></div>
        </template>
      );

      await click(".fk-d-menu__trigger");
      await focus("#trigger-input");
      await tab();
      assert.dom("#in-panel").isFocused("the trigger input enters the panel");

      await tab();
      assert
        .dom("#after-trigger")
        .isFocused("forward exit resumes after the trigger wrapper");
      assert.dom("#in-panel").doesNotExist("forward exit dismisses the panel");
    });

    test("a compound trigger finishes its own tab sequence before entering the panel", async function (assert) {
      await render(
        <template>
          <button type="button" id="before-trigger">before</button>
          {{#if this.outlet}}
            <DMenu
              @inline={{false}}
              @trapTab={{false}}
              @inlineTabOrder={{true}}
              @triggerComponent={{dElement "div"}}
              @portalOutletElement={{this.outlet}}
            >
              <:trigger>
                <input id="trigger-first" aria-label="first trigger control" />
                <button type="button" id="trigger-last">last trigger control</button>
              </:trigger>
              <:content>
                <button type="button" id="in-panel">panel action</button>
              </:content>
            </DMenu>
          {{/if}}
          <button type="button" id="after-trigger">after</button>
          <div id="outlet" {{didInsert this.setOutlet}}></div>
        </template>
      );

      await click(".fk-d-menu__trigger");
      await focus("#trigger-first");
      await tab();
      assert
        .dom("#trigger-last")
        .isFocused("Tab from an early trigger stop stays in the trigger");

      await tab();
      assert
        .dom("#in-panel")
        .isFocused("Tab from the trigger's last stop enters the panel");

      await tab({ backwards: true });
      assert
        .dom("#trigger-last")
        .isFocused("backward panel exit returns to the trigger's last stop");

      await click(".fk-d-menu__trigger");
      await focus("#trigger-first");
      await tab({ backwards: true });
      assert
        .dom("#before-trigger")
        .isFocused(
          "Shift+Tab from the trigger follows the page's backward order"
        );
    });

    test("Shift+Tab out of the float returns to the trigger", async function (assert) {
      await render(
        <template>
          {{#if this.outlet}}
            <DMenu
              @inline={{false}}
              @trapTab={{false}}
              @inlineTabOrder={{true}}
              @label="trigger"
              @portalOutletElement={{this.outlet}}
            >
              <:content>
                <button type="button" id="in-panel" class="in-panel">panel
                  action</button>
              </:content>
            </DMenu>
          {{/if}}
          <div id="outlet" {{didInsert this.setOutlet}}></div>
        </template>
      );

      await click(".fk-d-menu__trigger");
      await tab();
      assert.strictEqual(activeId(), "in-panel");

      await tab({ backwards: true });
      assert
        .dom(".fk-d-menu__trigger")
        .isFocused(
          "backwards off the first panel control is the trigger, where the reader came in"
        );
    });

    test("a float with nothing focusable is passed over", async function (assert) {
      await render(
        <template>
          {{#if this.outlet}}
            <DMenu
              @inline={{false}}
              @trapTab={{false}}
              @inlineTabOrder={{true}}
              @label="trigger"
              @portalOutletElement={{this.outlet}}
            >
              <:content>
                <p class="in-panel">nothing to focus here</p>
              </:content>
            </DMenu>
          {{/if}}
          <button
            type="button"
            id="after-trigger"
            class="after-trigger"
          >after</button>
          <div id="outlet" {{didInsert this.setOutlet}}></div>
        </template>
      );

      await click(".fk-d-menu__trigger");
      assert.dom("#outlet .in-panel").exists();

      // The fall-through path: a panel that is only a list must never pull focus in, since its
      // rows are reached with the arrow keys rather than by tabbing.
      await tab();
      assert
        .dom("#after-trigger")
        .isFocused("Tab passes a float that offers no stop of its own");
    });

    test("asserts when containment is asked for as well", async function (assert) {
      let fired = false;
      setupOnerror((error) => {
        fired = true;
        assert.true(
          error.message.includes("alternatives"),
          "the assertion says the two options are alternatives"
        );
      });

      await render(
        <template>
          {{#if this.outlet}}
            <DMenu
              @inline={{false}}
              @trapTab={{true}}
              @inlineTabOrder={{true}}
              @label="trigger"
              @portalOutletElement={{this.outlet}}
            >
              <:content>
                <button type="button" id="in-panel">panel action</button>
              </:content>
            </DMenu>
          {{/if}}
          <div id="outlet" {{didInsert this.setOutlet}}></div>
        </template>
      );

      await click(".fk-d-menu__trigger");

      // Also pins that the template reads the GETTER rather than the argument: routed around it,
      // the conflict would go back to being silent, with the trap quietly winning.
      assert.true(fired, "the conflicting configuration asserts");
    });

    test("without the option, Tab out of the float does not come back to the trigger", async function (assert) {
      await render(
        <template>
          {{#if this.outlet}}
            <DMenu
              @inline={{false}}
              @trapTab={{false}}
              @label="trigger"
              @portalOutletElement={{this.outlet}}
            >
              <:content>
                <button type="button" id="in-panel" class="in-panel">panel
                  action</button>
              </:content>
            </DMenu>
          {{/if}}
          <button
            type="button"
            id="after-trigger"
            class="after-trigger"
          >after</button>
          <div id="outlet" {{didInsert this.setOutlet}}></div>
        </template>
      );

      await click(".fk-d-menu__trigger");

      // Focus a panel control directly rather than tabbing to it: DMenu has its own older
      // `forwardTabToContent`, which pulls focus into the body on Tab whenever a body exists, so
      // the INTO direction is not a clean contrast. The OUT direction is.
      await click("#in-panel");
      assert.strictEqual(activeId(), "in-panel");

      // The defect the option exists to fix, pinned so it cannot quietly become a no-op. Native
      // order continues from the PORTAL, which is last in the document, so the field's neighbour
      // is never reached.
      await tab();
      assert
        .dom(".after-trigger")
        .isNotFocused(
          "without the repair, leaving the panel does not resume beside the trigger"
        );
    });

    test("tab stops honor disabled fieldset semantics", async function (assert) {
      await render(
        <template>
          <div id="root">
            <fieldset disabled>
              <legend><button id="first-legend">first legend</button></legend>
              <button id="fieldset-control">disabled control</button>
              <legend><button id="second-legend">second legend</button></legend>
            </fieldset>
            <button id="after-fieldset">after</button>
          </div>
        </template>
      );

      assert.deepEqual(
        tabStopsWithin(find("#root")).map((element) => element.id),
        ["first-legend", "after-fieldset"],
        "only the first legend escapes a disabled fieldset"
      );
    });

    test("tab stops use the checked radio as the group's single stop", async function (assert) {
      await render(
        <template>
          <input
            id="checked-outside"
            type="radio"
            name="outside-group"
            checked
          />
          <div id="root">
            <input id="unchecked" type="radio" name="group" />
            <input id="checked" type="radio" name="group" checked />
            <input id="unchecked-after" type="radio" name="group" />
            <input
              id="suppressed-by-outside"
              type="radio"
              name="outside-group"
            />
          </div>
        </template>
      );

      assert.deepEqual(
        tabStopsWithin(find("#root")).map((element) => element.id),
        ["checked"],
        "radio membership is resolved across the full document group"
      );
    });

    test("unchecked radio groups keep one stop and exit from a programmatically focused member", async function (assert) {
      await render(
        <template>
          <div id="root">
            <button id="before-radios">before</button>
            <input id="first-radio" type="radio" name="group" />
            <input id="focused-radio" type="radio" name="group" />
            <button id="after-radios">after</button>
            <form id="form-a">
              <input id="form-a-radio" type="radio" name="shared" />
            </form>
            <form id="form-b">
              <input id="form-b-radio" type="radio" name="shared" />
            </form>
          </div>
        </template>
      );

      const root = find("#root");
      const focusedRadio = find("#focused-radio");

      assert.deepEqual(
        tabStopsWithin(root).map((element) => element.id),
        [
          "before-radios",
          "first-radio",
          "after-radios",
          "form-a-radio",
          "form-b-radio",
        ],
        "an unchecked group exposes its first member, while separate forms expose one each"
      );
      assert.strictEqual(
        adjacentTabStop(focusedRadio, { forward: false, root })?.id,
        "before-radios",
        "Shift+Tab exits an unchecked group from a programmatically focused non-stop"
      );
      assert.strictEqual(
        adjacentTabStop(focusedRadio, { forward: true, root })?.id,
        "after-radios",
        "Tab exits an unchecked group from a programmatically focused non-stop"
      );
    });

    test("tab stops sort positive tabindex before the regular sequence", async function (assert) {
      await render(
        <template>
          <div id="root">
            <button id="regular-first">regular first</button>
            <button id="positive-two" tabindex="2">positive two</button>
            <button id="positive-one-a" tabindex="1">positive one a</button>
            <button id="positive-one-b" tabindex="1">positive one b</button>
            <button id="regular-last">regular last</button>
          </div>
        </template>
      );

      assert.deepEqual(
        tabStopsWithin(find("#root")).map((element) => element.id),
        [
          "positive-one-a",
          "positive-one-b",
          "positive-two",
          "regular-first",
          "regular-last",
        ],
        "positive values are ascending and ties retain document order"
      );
    });

    test("tab stops follow keyboard visibility rather than the accessibility tree", async function (assert) {
      await render(
        <template>
          <div id="root">
            <button id="aria-hidden" aria-hidden="true">aria hidden</button>
            <button id="transparent" style="opacity: 0">transparent</button>
            <button id="visibility-hidden" style="visibility: hidden">visibility
              hidden</button>
            <button id="display-none" style="display: none">display none</button>
            <div inert><button id="inert">inert</button></div>
          </div>
        </template>
      );

      assert.deepEqual(
        tabStopsWithin(find("#root")).map((element) => element.id),
        ["aria-hidden", "transparent"],
        "ARIA and opacity do not remove focus, while CSS visibility and inertness do"
      );
    });
  }
);
