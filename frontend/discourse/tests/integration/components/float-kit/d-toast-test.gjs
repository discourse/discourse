import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { render, triggerEvent, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import DToast from "discourse/float-kit/components/d-toast";
import DToastInstance from "discourse/float-kit/lib/d-toast-instance";
import { withSilencedDeprecationsAsync } from "discourse/lib/deprecated";
import { forceMobile } from "discourse/lib/mobile";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

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

module("Integration | Component | FloatKit | DToast", function (hooks) {
  setupRenderingTest(hooks);

  test("touch movement without native scrolling does not close", async function (assert) {
    let closing = false;
    forceMobile();
    const toast = createCustomToastInstance(getOwner(this), {}, () => {
      closing = true;
    });

    await render(
      <template>
        <section class="fk-d-toasts"><DToast @toast={{toast}} /></section>
      </template>
    );
    await waitFor(".d-toast");

    assert
      .dom(".d-toast")
      .doesNotHaveAttribute("role", "the toast preset has no sheet role");

    await triggerEvent(".d-toast", "touchstart", {
      touches: [{ clientX: 0, clientY: 0 }],
      changedTouches: [{ clientX: 0, clientY: 0 }],
    });

    await triggerEvent(".d-toast", "touchmove", {
      touches: [{ clientX: 0, clientY: -100 }],
      changedTouches: [{ clientX: 0, clientY: -100 }],
    });

    await triggerEvent(".d-toast", "touchend", {
      touches: [{ clientX: 0, clientY: -100 }],
      changedTouches: [{ clientX: 0, clientY: -100 }],
    });

    assert.false(
      closing,
      "touch events only update touch state; native scrolling owns swipe dismissal"
    );
  });

  test("duration", async function (assert) {
    let toast = new DToastInstance(getOwner(this), {
      duration: 9999,
      data: { message: "test" },
    });
    await withSilencedDeprecationsAsync(
      "float-kit.d-toast.duration",
      async () =>
        assert.strictEqual(
          toast.duration,
          9999,
          "it accepts an arbitrary duration for backwards compatibility"
        )
    );

    toast = new DToastInstance(getOwner(this), {
      duration: "short",
      data: { message: "test" },
    });
    assert.strictEqual(toast.duration, 3000, "it converts `short` to 3000ms");

    toast = new DToastInstance(getOwner(this), {
      duration: "long",
      data: { message: "test" },
    });
    assert.strictEqual(toast.duration, 5000, "it converts `long` to 5000ms");
  });
});
