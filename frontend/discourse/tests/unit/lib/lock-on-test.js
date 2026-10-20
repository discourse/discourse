import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import LockOn from "discourse/lib/lock-on";

module("Unit | Utility | lock-on", function (hooks) {
  setupTest(hooks);

  test("stops polling for a missing element once it times out", async function (assert) {
    const clock = sinon.useFakeTimers({ toFake: ["Date"] });
    const finished = sinon.spy();

    new LockOn("#missing-element", { finished }).lock();
    clock.tick(10_000);
    await new Promise(requestAnimationFrame);
    await new Promise(requestAnimationFrame);

    assert.true(finished.calledOnce, "finishes exactly once");
  });
});
