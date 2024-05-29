import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import runAfterFramePaint from "discourse/lib/after-frame-paint";

module("Unit | Lib | afterFramePaint", function (hooks) {
  setupTest(hooks);

  test("should run callback correctly", async function (assert) {
    let callbackDone = false;
    runAfterFramePaint(() => (callbackDone = true));
    assert.false(callbackDone, "callback was not run immediately");
    await settled();
    assert.true(callbackDone, "callback was run before settled resolved");
  });
});
