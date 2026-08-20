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
