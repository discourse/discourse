import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import {
  click,
  find,
  focus,
  render,
  settled,
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
 * every case here forces the portal on with `@inline={{false}}` and points it at an outlet placed
 * away from the trigger, reproducing the real arrangement, where the portal's position is not the
 * trigger's, and where native Tab out of the panel would therefore land in the wrong place.
 *
 * The outlet usually sits LAST in the document, so DOM order is trigger → neighbour → portal. One
 * case moves it BETWEEN the two instead, which is the only arrangement where the panel is itself
 * the next stop after the trigger, and so the only one that can pin that the search for that stop
 * excludes the panel.
 *
 * Each menu waits on `{{#if this.outlet}}`: the outlet element only exists after its own insert
 * hook runs, and `{{#in-element}}` rejects a nullish destination. The menu still renders in its
 * template position.
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
              @inlineTabOrder={{true}}
              @label="trigger"
              @portalOutletElement={{this.outlet}}
            >
              <:content>
                <button class="in-panel" id="in-panel" type="button">panel
                  action</button>
              </:content>
            </DMenu>
          {{/if}}
          <button
            class="after-trigger"
            id="after-trigger"
            type="button"
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

    test("the option alone is enough, without turning containment off by hand", async function (assert) {
      await render(
        <template>
          {{#if this.outlet}}
            <DMenu
              @inline={{false}}
              @inlineTabOrder={{true}}
              @label="trigger"
              @portalOutletElement={{this.outlet}}
            >
              <:content>
                <button id="in-panel" type="button">panel action</button>
              </:content>
            </DMenu>
          {{/if}}
          <button id="after-trigger" type="button">after</button>
          <div id="outlet" {{didInsert this.setOutlet}}></div>
        </template>
      );

      await click(".fk-d-menu__trigger");

      // A menu traps Tab by default, so the option has to be enough on its own: requiring the
      // trap to be switched off too would make every call site carry a second flag.
      await tab();
      assert
        .dom("#in-panel")
        .isFocused(
          "Tab enters the panel without the trap being switched off too"
        );

      await tab();
      assert
        .dom("#after-trigger")
        .isFocused("and leaving it still resumes beside the trigger");
    });

    test("Tab visits every panel control before the float is left", async function (assert) {
      await render(
        <template>
          {{#if this.outlet}}
            <DMenu
              @inline={{false}}
              @inlineTabOrder={{true}}
              @label="trigger"
              @portalOutletElement={{this.outlet}}
            >
              <:content>
                <input aria-label="filter" id="panel-filter" />
                <button id="panel-action" type="button">panel action</button>
              </:content>
            </DMenu>
          {{/if}}
          <button id="after-trigger" type="button">after</button>
          <div id="outlet" {{didInsert this.setOutlet}}></div>
        </template>
      );

      await click(".fk-d-menu__trigger");

      await tab();
      assert
        .dom("#panel-filter")
        .isFocused("Tab enters at the panel's first stop");

      // Movement WITHIN the panel: the modifier drives it from its own local sequence rather than
      // leaving it to the browser, so a second control must be reached before the float is left.
      await tab();
      assert
        .dom("#panel-action")
        .isFocused("Tab reaches the panel's next control instead of leaving");

      await tab({ backwards: true });
      assert
        .dom("#panel-filter")
        .isFocused("Shift+Tab moves back within the panel");

      await tab();
      await tab();
      assert
        .dom("#after-trigger")
        .isFocused("only the stop past the LAST control leaves the panel");
      assert
        .dom("#panel-action")
        .doesNotExist("and leaving it dismisses the float");
    });

    test("the forward exit steps over the panel to reach the trigger's neighbour", async function (assert) {
      await render(
        <template>
          {{#if this.outlet}}
            <DMenu
              @inline={{false}}
              @inlineTabOrder={{true}}
              @label="trigger"
              @portalOutletElement={{this.outlet}}
            >
              <:content>
                <button id="in-panel" type="button">panel action</button>
              </:content>
            </DMenu>
          {{/if}}
          {{! The outlet sits BETWEEN the trigger and its neighbour, so the panel's own control is
              the next stop in document order. Searching the page for the stop after the trigger
              has to exclude the panel, or the forward exit lands back inside the float it is
              dismissing. }}
          <div id="outlet" {{didInsert this.setOutlet}}></div>
          <button id="after-trigger" type="button">after</button>
        </template>
      );

      await click(".fk-d-menu__trigger");
      await tab();
      assert
        .dom("#in-panel")
        .isFocused("Tab from the trigger enters the panel");

      await tab();
      assert
        .dom("#after-trigger")
        .isFocused(
          "the panel is not a candidate for the stop after the trigger"
        );
      assert.dom("#in-panel").doesNotExist("the float is dismissed on the way");
    });

    test("a non-focusable trigger wrapper resumes from its last stop", async function (assert) {
      await render(
        <template>
          {{#if this.outlet}}
            <DMenu
              @inline={{false}}
              @inlineTabOrder={{true}}
              @portalOutletElement={{this.outlet}}
              @triggerComponent={{dElement "div"}}
            >
              <:trigger>
                <input aria-label="trigger" id="trigger-input" />
              </:trigger>
              <:content>
                <button id="in-panel" type="button">panel action</button>
              </:content>
            </DMenu>
          {{/if}}
          <button id="after-trigger" type="button">after</button>
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
          <button id="before-trigger" type="button">before</button>
          {{#if this.outlet}}
            <DMenu
              @inline={{false}}
              @inlineTabOrder={{true}}
              @portalOutletElement={{this.outlet}}
              @triggerComponent={{dElement "div"}}
            >
              <:trigger>
                <input aria-label="first trigger control" id="trigger-first" />
                <button id="trigger-last" type="button">last trigger control</button>
              </:trigger>
              <:content>
                <button id="in-panel" type="button">panel action</button>
              </:content>
            </DMenu>
          {{/if}}
          <button id="after-trigger" type="button">after</button>
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
              @inlineTabOrder={{true}}
              @label="trigger"
              @portalOutletElement={{this.outlet}}
            >
              <:content>
                <button class="in-panel" id="in-panel" type="button">panel
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
            class="after-trigger"
            id="after-trigger"
            type="button"
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
              @inlineTabOrder={{true}}
              @label="trigger"
              @portalOutletElement={{this.outlet}}
              @trapTab={{true}}
            >
              <:content>
                <button id="in-panel" type="button">panel action</button>
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
              @label="trigger"
              @portalOutletElement={{this.outlet}}
              @trapTab={{false}}
            >
              <:content>
                <button class="in-panel" id="in-panel" type="button">panel
                  action</button>
              </:content>
            </DMenu>
          {{/if}}
          <button
            class="after-trigger"
            id="after-trigger"
            type="button"
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
            checked
            id="checked-outside"
            name="outside-group"
            type="radio"
          />
          <div id="root">
            <input id="unchecked" name="group" type="radio" />
            <input checked id="checked" name="group" type="radio" />
            <input id="unchecked-after" name="group" type="radio" />
            <input
              id="suppressed-by-outside"
              name="outside-group"
              type="radio"
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
            <input id="first-radio" name="group" type="radio" />
            <input id="focused-radio" name="group" type="radio" />
            <button id="after-radios">after</button>
            <form id="form-a">
              <input id="form-a-radio" name="shared" type="radio" />
            </form>
            <form id="form-b">
              <input id="form-b-radio" name="shared" type="radio" />
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

    test("tab stops drop an ignored subtree and the stops inside it", async function (assert) {
      await render(
        <template>
          <div id="root">
            <button id="before-panel">before</button>
            <div id="panel">
              <input aria-label="filter" id="panel-filter" />
              <button id="panel-action">panel action</button>
            </div>
            <button id="after-panel">after</button>
          </div>
        </template>
      );

      const root = find("#root");
      const panel = find("#panel");

      assert.deepEqual(
        tabStopsWithin(root, { ignore: panel }).map((element) => element.id),
        ["before-panel", "after-panel"],
        "the ignored element and its descendants are both excluded"
      );
      assert.strictEqual(
        adjacentTabStop(find("#before-panel"), {
          forward: true,
          ignore: panel,
          root,
        })?.id,
        "after-panel",
        "the stop after an anchor skips the ignored subtree entirely"
      );
    });

    test("each call re-measures instead of answering from an earlier one", async function (assert) {
      await render(
        <template>
          {{! Names unique to this test: group membership is resolved by querying the whole
              document, so a name shared with another fixture would make the two depend on
              teardown order. }}
          <div id="root">
            <button id="rescan-control">control</button>
            <input id="rescan-first-radio" name="rescan-group" type="radio" />
            {{#if this.showLateRadio}}
              <input
                checked
                id="rescan-late-radio"
                name="rescan-group"
                type="radio"
              />
            {{/if}}
          </div>
        </template>
      );

      const root = find("#root");

      assert.deepEqual(
        tabStopsWithin(root).map((element) => element.id),
        ["rescan-control", "rescan-first-radio"],
        "the unchecked group starts out represented by its first member"
      );

      // Both answers above are measured, not derived: tabbability comes from live layout and
      // state, and a group's representative from the radios present at the time. Reusing either
      // measurement past the call that took it would report the DOM as it used to be.
      find("#rescan-control").tabIndex = -1;
      this.set("showLateRadio", true);
      await settled();

      assert.deepEqual(
        tabStopsWithin(root).map((element) => element.id),
        ["rescan-late-radio"],
        "the opted-out control is gone and the newly checked radio represents the group"
      );
    });

    test("tab stops follow keyboard visibility rather than the accessibility tree", async function (assert) {
      await render(
        <template>
          <div id="root">
            <button aria-hidden="true" id="aria-hidden">aria hidden</button>
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
