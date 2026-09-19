import { getOwner } from "@ember/owner";
import {
  clearRender,
  find,
  render,
  settled,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import ComposerContainer from "discourse/components/composer-container";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { dragPointer } from "discourse/tests/helpers/ui-kit/pointer-gesture-helper";

/**
 * Releases a key on the separator without bubbling.
 *
 * The separator's own listener is what commits the resize, and it sits on the
 * element. A bubbling release would additionally reach the composer body, whose
 * keyup handler drives typing state against a composer model this fixture has no
 * reason to build.
 */
async function releaseKey(selector, key) {
  find(selector).dispatchEvent(
    new KeyboardEvent("keyup", { key, bubbles: false })
  );
  await settled();
}

module("Integration | Component | ComposerContainer", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    const appEvents = getOwner(this).lookup("service:app-events");
    this.recordLifecycle = (assert) => {
      appEvents.on("composer:resize-started", () => assert.step("started"));
      appEvents.on("composer:resize-ended", () => assert.step("ended"));
    };
  });

  hooks.afterEach(function () {
    // Written on the document rather than on anything this test rendered, so it
    // outlives the component unless it is taken back.
    document.documentElement.style.removeProperty("--composer-height");
  });

  test("teardown with a resize still open ends it", async function (assert) {
    this.recordLifecycle(assert);

    await render(<template><ComposerContainer /></template>);

    // Held rather than released, so the composer dies mid-gesture. The resize
    // modifier fires no callback of its own when torn down that way.
    await dragPointer(".grippie", { from: 500, to: 400, release: false });
    assert.verifySteps(["started"], "the gesture is open and unclosed");

    await clearRender();

    assert.verifySteps(
      ["ended"],
      "teardown closes the resize rather than stranding subscribers that undo something on the end"
    );
  });

  test("a resize that already ended is not ended twice", async function (assert) {
    this.recordLifecycle(assert);

    await render(<template><ComposerContainer /></template>);

    await dragPointer(".grippie", { from: 500, to: 400 });
    assert.verifySteps(
      ["started", "ended"],
      "releasing the pointer ends the resize"
    );

    await clearRender();

    assert.verifySteps([], "teardown has nothing left to close");
  });

  test("a held key is one resize that commits when it is released", async function (assert) {
    this.recordLifecycle(assert);
    const keyValueStore = getOwner(this).lookup("service:key-value-store");
    const setSpy = sinon.spy(keyValueStore, "set");

    await render(<template><ComposerContainer /></template>);

    await triggerKeyEvent(".grippie", "keydown", "End");
    await triggerKeyEvent(".grippie", "keydown", "End", { repeat: true });

    assert.verifySteps(
      ["started"],
      "the repeat belongs to the gesture the first press opened"
    );
    assert.strictEqual(
      setSpy.callCount,
      0,
      "nothing is persisted while the key is still held"
    );

    const height =
      document.documentElement.style.getPropertyValue("--composer-height");
    assert.notStrictEqual(height, "", "the held key previewed a height");

    await releaseKey(".grippie", "End");

    assert.verifySteps(["ended"], "releasing the key ends the resize");
    assert.strictEqual(
      setSpy.callCount,
      1,
      "and persists once, on the release rather than per repeat"
    );
    assert.deepEqual(
      setSpy.firstCall?.args,
      [{ key: "composerHeight", value: height }],
      "persisting the height the gesture settled on"
    );
  });
});
