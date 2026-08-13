import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { click, render, setupOnerror, tab } from "@ember/test-helpers";
import { module, test } from "qunit";
import DMenu from "discourse/float-kit/components/d-menu";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

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
 * out. That case is only observable in a real browser, and is covered by a system spec.
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

      // The fall-through path, and the reason this is safe to leave on by default: a panel that
      // is only a list must never pull focus in, since its rows are reached with the arrow keys.
      //
      // Asserted as "focus did not enter the float" rather than "focus reached the neighbour",
      // because where the press ends up is not this modifier's to decide once it declines. A bare
      // DMenu still has its older `forwardTabToContent`, which swallows the press on a body with
      // nothing focusable in it (`firstFocusable` is null and `#body.focus()` is a no-op), leaving
      // focus on the trigger. DSelect stops that from reaching the trigger; this test does not,
      // and should not pin behaviour it does not own.
      await tab();
      assert.false(
        document.querySelector("#outlet").contains(document.activeElement),
        "focus never enters a float that offers no stop of its own"
      );
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
  }
);
