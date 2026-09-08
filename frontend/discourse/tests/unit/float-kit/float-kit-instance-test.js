import { destroy } from "@ember/destroyable";
import { setOwner } from "@ember/owner";
import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import FloatKitInstance from "discourse/float-kit/lib/float-kit-instance";

class TestFloatKitInstance extends FloatKitInstance {
  options = { hoverGracePeriod: 10, listeners: false };
  trigger = document.createElement("button");
  expanded = true;
  closeCount = 0;

  get portalOutletElement() {
    return null;
  }

  async close() {
    this.closeCount++;
  }

  async closeWithBaseLifecycle() {
    await super.close();
  }

  async onClick() {}
  async onPointerLeave() {}
  async onPointerMove() {}
  async onTrigger() {}
}

module("Unit | FloatKit | FloatKitInstance", function () {
  test("teardown cancels a pending hover close", async function (assert) {
    const instance = new TestFloatKitInstance();

    instance.scheduleHoverClose();
    instance.tearDownListeners();
    await new Promise((resolve) => setTimeout(resolve, 30));

    assert.strictEqual(
      instance.closeCount,
      0,
      "the timer does not close an instance after teardown"
    );
  });

  test("close releases the hover focus lock", async function (assert) {
    const instance = new TestFloatKitInstance();

    instance.lockHoverCloseForFocus();
    await instance.closeWithBaseLifecycle();
    instance.scheduleHoverClose();
    await new Promise((resolve) => setTimeout(resolve, 30));

    assert.strictEqual(
      instance.closeCount,
      1,
      "a later hover close can run after the float has closed"
    );
  });
});

class TouchFloatKitInstance extends FloatKitInstance {
  expanded = false;
  options = {};
  portalOutletElement = null;

  async onClick() {}

  async onPointerLeave() {}

  async onPointerMove() {}

  async onTrigger() {}
}

module("Unit | FloatKit | float-kit-instance", function (hooks) {
  setupTest(hooks);

  test("a held touch does not trigger after owner destruction begins", async function (assert) {
    const owner = {};
    const instance = new TouchFloatKitInstance();
    const trigger = document.createElement("button");
    const event = {
      stopPropagation() {},
      touches: [{}],
    };

    setOwner(instance, owner);
    instance.trigger = trigger;
    instance.onTrigger = () => assert.step("trigger");

    instance.onTouchStart(event);
    await settled();

    instance.onTouchStart(event);
    destroy(owner);
    await settled();

    assert.verifySteps(
      ["trigger"],
      "the live touch triggers, but the touch pending during owner teardown does not"
    );
  });
});
