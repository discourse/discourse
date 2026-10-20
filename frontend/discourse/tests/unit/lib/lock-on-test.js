import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import LockOn from "discourse/lib/lock-on";
import { headerOffset } from "discourse/lib/offset-calculator";
import { fixture } from "discourse/tests/helpers/qunit-helpers";

module("Unit | Utility | lock-on", function (hooks) {
  setupTest(hooks);

  test("keeps the element's scroll margin above it", function (assert) {
    const target = document.createElement("div");
    target.id = "lock-on-target";
    target.style.scrollMarginTop = "100px";
    fixture().append(target);
    const top = target.getBoundingClientRect().top + window.scrollY;

    const elementTop = new LockOn("#lock-on-target").elementTop();

    assert.strictEqual(
      elementTop,
      top - headerOffset() - 100,
      "leaves the scroll margin above the element"
    );
  });

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
