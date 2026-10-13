import { destroy } from "@ember/destroyable";
import { setOwner } from "@ember/owner";
import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import FloatKitInstance from "discourse/float-kit/lib/float-kit-instance";

class TestFloatKitInstance extends FloatKitInstance {
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
    const instance = new TestFloatKitInstance();
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
