import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { find, render, settled, triggerEvent } from "@ember/test-helpers";
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

  test("a cancelled swipe settles the toast back", async function (assert) {
    forceMobile();
    // a long duration keeps the auto-close timer out of this test
    const toast = createCustomToastInstance(
      getOwner(this),
      { duration: "long" },
      () => {}
    );

    await render(<template><DToast @toast={{toast}} /></template>);

    const wrapper = find(".fk-d-toast");
    let time = 1000;
    // synthetic events land milliseconds apart, which reads as a flick fast
    // enough for the drag itself to dismiss; spacing them keeps it a drag
    const touch = (type, y, afterMs = 400) => {
      time += afterMs;
      const point = [{ clientX: 0, clientY: y }];
      const event = new Event(type, { bubbles: true, cancelable: true });
      Object.defineProperty(event, "timeStamp", { value: time });
      event.touches = type === "touchcancel" ? [] : point;
      event.changedTouches = point;
      wrapper.dispatchEvent(event);
    };
    const offsetOf = () => {
      const { transform } = window.getComputedStyle(wrapper);
      return transform === "none" ? 0 : new DOMMatrixReadOnly(transform).m42;
    };

    touch("touchstart", 0);
    // the first move only starts the gesture; the second is the one that paints
    touch("touchmove", -20);
    touch("touchmove", -40);
    await new Promise((resolve) => requestAnimationFrame(resolve));
    await settled();

    assert.true(offsetOf() < 0, "the drag carried the toast up");

    // the drag paints fill-forwards, so a gesture the browser takes away has to
    // be undone or the toast stays where the finger left it
    touch("touchcancel", -40);
    await settled();

    assert.strictEqual(offsetOf(), 0, "the toast returns to rest");
  });

  test("duration", async function (assert) {
    let toast = new DToastInstance(getOwner(this), {
      duration: 9999,
      data: { message: "test" },
    });
    await withSilencedDeprecationsAsync(
      "float-kit.d-toast.duration",
      async () => await render(<template><DToast @toast={{toast}} /></template>)
    );

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
