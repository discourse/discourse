import { click, find, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import DMenus from "discourse/float-kit/components/d-menus";
import dContextMenu from "discourse/float-kit/modifiers/d-context-menu";
import isContextMenuExemptTarget from "discourse/lib/is-context-menu-exempt-target";
import virtualElementFromPoint from "discourse/lib/virtual-element-from-point";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DButton from "discourse/ui-kit/d-button";

const Actions = <template>
  <DButton class="ctx-action" @action={{@close}}>Act</DButton>
</template>;

/**
 * Dispatches a real contextmenu event and hands the event back, so a test can see whether
 * anything called preventDefault on it. `triggerEvent` resolves to nothing, so it cannot
 * answer that question.
 */
async function rightClick(selector, { clientX = 40, clientY = 60 } = {}) {
  const event = new MouseEvent("contextmenu", {
    bubbles: true,
    cancelable: true,
    clientX,
    clientY,
  });
  find(selector).dispatchEvent(event);
  await settled();
  return event;
}

module("Integration | Component | FloatKit | dContextMenu", function (hooks) {
  setupRenderingTest(hooks);

  test("ctx-oracle: builds a zero-size reference at the given point", function (assert) {
    const reference = virtualElementFromPoint(120, 250);
    const rect = reference.getBoundingClientRect();

    assert.strictEqual(rect.width, 0, "the reference has no width");
    assert.strictEqual(rect.height, 0, "the reference has no height");
    assert.strictEqual(rect.left, 120, "left is the supplied x");
    assert.strictEqual(rect.right, 120, "right collapses onto the same x");
    assert.strictEqual(rect.top, 250, "top is the supplied y");
    assert.strictEqual(rect.bottom, 250, "bottom collapses onto the same y");
    assert.strictEqual(
      reference.contextElement,
      undefined,
      "no contextElement, so the reference keeps viewport clipping and no scale divisor"
    );
  });

  test("ctx-oracle: exempts targets that own a text caret", async function (assert) {
    await render(
      <template>
        <textarea class="probe-textarea"></textarea>
        <input class="probe-text" type="text" />
        <input class="probe-checkbox" type="checkbox" />
        <div class="probe-editable" contenteditable="true"></div>
        <select class="probe-select"><option>a</option></select>
        <button class="probe-button" type="button">b</button>
      </template>
    );

    assert.true(
      isContextMenuExemptTarget(find(".probe-textarea")),
      "a textarea keeps the native menu"
    );
    assert.true(
      isContextMenuExemptTarget(find(".probe-text")),
      "a text input keeps the native menu"
    );
    assert.true(
      isContextMenuExemptTarget(find(".probe-editable")),
      "a contenteditable region keeps the native menu"
    );
    assert.false(
      isContextMenuExemptTarget(find(".probe-checkbox")),
      "a checkbox owns no caret"
    );
    assert.false(
      isContextMenuExemptTarget(find(".probe-button")),
      "a button owns no caret"
    );
    assert.false(
      isContextMenuExemptTarget(find(".probe-select")),
      "a select owns no caret, unlike the arrow-key predicate this is derived from"
    );
    assert.false(
      isContextMenuExemptTarget(null),
      "a missing target is not exempt"
    );
  });

  test("ctx-oracle: an accepted right-click opens a menu and suppresses the native one", async function (assert) {
    await render(
      <template>
        <div class="ctx-host" {{dContextMenu component=Actions}}>host</div>
        <DMenus />
      </template>
    );

    const event = await rightClick(".ctx-host");

    assert.dom(".fk-d-menu .ctx-action").exists("the menu opened");
    assert.true(
      event.defaultPrevented,
      "the native menu is suppressed only because a handler accepted"
    );
  });

  test("ctx-oracle: a declining hook leaves the event untouched", async function (assert) {
    const consulted = [];
    const decline = (event) => {
      consulted.push(event.type);
      return false;
    };

    await render(
      <template>
        <div
          class="ctx-host"
          {{dContextMenu component=Actions beforeContextMenu=decline}}
        >host</div>
        <DMenus />
      </template>
    );

    const event = await rightClick(".ctx-host");

    // Without this the test would pass against a modifier that does nothing at all, since the
    // remaining assertions only check that nothing happened.
    assert.deepEqual(
      consulted,
      ["contextmenu"],
      "the hook was consulted, so the decline was a decision rather than an absent listener"
    );
    assert.dom(".fk-d-menu").doesNotExist("no menu opened");
    assert.false(
      event.defaultPrevented,
      "the native menu survives a decline, so the browser still gets the gesture"
    );
  });

  test("ctx-oracle: an accepted inner handler stops the event reaching an outer one", async function (assert) {
    const outerSeen = [];
    const recordOuter = () => {
      outerSeen.push("outer");
      return false;
    };

    await render(
      <template>
        <div
          class="ctx-outer"
          {{dContextMenu component=Actions beforeContextMenu=recordOuter}}
        >
          <div class="ctx-inner" {{dContextMenu component=Actions}}>inner</div>
        </div>
        <DMenus />
      </template>
    );

    await rightClick(".ctx-inner");

    assert.dom(".fk-d-menu").exists("the innermost handler opened its menu");
    assert.deepEqual(
      outerSeen,
      [],
      "the outer handler never ran, because accepting stops propagation"
    );
  });

  test("ctx-oracle: a declining inner handler lets an outer one accept", async function (assert) {
    const declineInner = () => false;

    await render(
      <template>
        <div class="ctx-outer" {{dContextMenu component=Actions}}>
          <div
            class="ctx-inner"
            {{dContextMenu component=Actions beforeContextMenu=declineInner}}
          >inner</div>
        </div>
        <DMenus />
      </template>
    );

    const event = await rightClick(".ctx-inner");

    assert
      .dom(".fk-d-menu")
      .exists("the outer handler took the gesture the inner one declined");
    assert.true(event.defaultPrevented, "the outer handler accepted it");
  });

  test("ctx-oracle: an editable target declines without a hook", async function (assert) {
    await render(
      <template>
        <div class="ctx-host" {{dContextMenu component=Actions}}>
          <textarea class="ctx-textarea"></textarea>
          <span class="ctx-plain">plain</span>
        </div>
        <DMenus />
      </template>
    );

    const event = await rightClick(".ctx-textarea");

    assert
      .dom(".fk-d-menu")
      .doesNotExist("no menu over a caret-owning control");
    assert.false(
      event.defaultPrevented,
      "the browser keeps its spelling and clipboard menu"
    );

    // Control: the same host must still open elsewhere, or this test would pass against a
    // modifier that never opens anything.
    await rightClick(".ctx-plain");
    assert
      .dom(".fk-d-menu")
      .exists("the same host opens for a target that owns no caret");
  });

  test("ctx-oracle: right-clicking again moves the menu instead of leaving a second one", async function (assert) {
    await render(
      <template>
        <div class="ctx-host" {{dContextMenu component=Actions}}>host</div>
        <DMenus />
      </template>
    );

    await rightClick(".ctx-host", { clientX: 30, clientY: 40 });
    assert.dom(".fk-d-menu").exists({ count: 1 }, "one menu after the first");

    await rightClick(".ctx-host", { clientX: 300, clientY: 400 });
    assert
      .dom(".fk-d-menu")
      .exists({ count: 1 }, "still exactly one menu after reopening");
  });

  test("ctx-oracle: a keyboard-invoked right-click takes focus and gives it back, with nothing wired", async function (assert) {
    await render(
      <template>
        <div class="ctx-host" tabindex="0" {{dContextMenu component=Actions}}>
          host
        </div>
        <DMenus />
      </template>
    );

    // The platform dispatches this same event for the context-menu key, so a focusable target
    // is the whole consumer obligation.
    find(".ctx-host").focus();
    await rightClick(".ctx-host");

    assert.true(
      find(".fk-d-menu").contains(document.activeElement),
      "focus moved into the menu, so the items are reachable without a pointer"
    );

    await click(".fk-d-menu .ctx-action");

    assert
      .dom(".ctx-host")
      .isFocused(
        "closing returned focus to the element the modifier is installed on"
      );
  });

  test("ctx-oracle: the focus defaults are overridable in both directions", async function (assert) {
    const elsewhere = () => find(".ctx-elsewhere");

    await render(
      <template>
        <div
          class="ctx-host"
          tabindex="0"
          {{dContextMenu component=Actions autofocus=false}}
        >host</div>
        <div
          class="ctx-other"
          tabindex="0"
          {{dContextMenu component=Actions focusTarget=elsewhere}}
        >other</div>
        <button class="ctx-elsewhere" type="button">elsewhere</button>
        <DMenus />
      </template>
    );

    find(".ctx-host").focus();
    await rightClick(".ctx-host");
    assert.dom(".ctx-host").isFocused("autofocus=false keeps focus outside");
    await click(".fk-d-menu .ctx-action");

    find(".ctx-other").focus();
    await rightClick(".ctx-other");
    await click(".fk-d-menu .ctx-action");
    assert
      .dom(".ctx-elsewhere")
      .isFocused("an explicit focusTarget still wins over the element default");
  });

  test("ctx-oracle: removing the element closes the menu it opened", async function (assert) {
    await render(
      <template>
        {{#unless this.hidden}}
          <div class="ctx-host" {{dContextMenu component=Actions}}>host</div>
        {{/unless}}
        <DMenus />
      </template>
    );

    await rightClick(".ctx-host");
    assert.dom(".fk-d-menu").exists("the menu is open");

    this.set("hidden", true);
    await settled();

    assert.dom(".ctx-host").doesNotExist("the trigger element is gone");
    assert
      .dom(".fk-d-menu")
      .doesNotExist("its menu went with it, rather than floating detached");
  });
});
