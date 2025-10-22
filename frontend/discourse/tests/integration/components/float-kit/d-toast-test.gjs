import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { forceMobile } from "discourse/lib/mobile";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  disableRaiseOnDeprecation,
  enableRaiseOnDeprecation,
} from "discourse/tests/helpers/raise-on-deprecation";
import DToast from "float-kit/components/d-toast";
import DToastInstance from "float-kit/lib/d-toast-instance";

function createCustomToastInstance(owner, options, newClose) {
  class CustomToastInstance extends DToastInstance {
    constructor() {
      super(owner, options);
    }

    @action
    close() {
      newClose.apply(this);
    }
  }

  return new CustomToastInstance(owner, options);
}

module("Integration | Component | FloatKit | d-toast", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    disableRaiseOnDeprecation();
  });

  hooks.afterEach(function () {
    enableRaiseOnDeprecation();
  });

  test("swipe up to close", async function (assert) {
    let closing = false;
    forceMobile();
    const toast = createCustomToastInstance(getOwner(this), {}, () => {
      closing = true;
    });

    await render(<template><DToast @toast={{toast}} /></template>);

    assert.dom(".fk-d-toast").exists();

    await triggerEvent(".fk-d-toast", "touchstart", {
      touches: [{ clientX: 0, clientY: 0 }],
      changedTouches: [{ clientX: 0, clientY: 0 }],
    });

    await triggerEvent(".fk-d-toast", "touchmove", {
      touches: [{ clientX: 0, clientY: -100 }],
      changedTouches: [{ clientX: 0, clientY: -100 }],
    });

    await triggerEvent(".fk-d-toast", "touchend", {
      touches: [{ clientX: 0, clientY: -100 }],
      changedTouches: [{ clientX: 0, clientY: -100 }],
    });

    assert.true(closing);
  });

  test("duration", async function (assert) {
    let toast = new DToastInstance(getOwner(this), {
      duration: 9999,
      data: { message: "test" },
    });
    await render(<template><DToast @toast={{toast}} /></template>);

    assert
      .dom(".fk-d-toast")
      .hasAttribute(
        "data-test-duration",
        "9999",
        "it accepts an arbitrary duration for backwards compatibility"
      );

    toast = new DToastInstance(getOwner(this), {
      duration: "short",
      data: { message: "test" },
    });
    await render(<template><DToast @toast={{toast}} /></template>);

    assert
      .dom(".fk-d-toast")
      .hasAttribute(
        "data-test-duration",
        "3000",
        "it `converts `short` to 3000ms"
      );

    toast = new DToastInstance(getOwner(this), {
      duration: "long",
      data: { message: "test" },
    });
    await render(<template><DToast @toast={{toast}} /></template>);

    assert
      .dom(".fk-d-toast")
      .hasAttribute(
        "data-test-duration",
        "5000",
        "it `converts `long` to 5000ms"
      );
  });
});
