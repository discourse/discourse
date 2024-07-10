import { getOwner } from "@ember/application";
import { action } from "@ember/object";
import { render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DToast from "float-kit/components/d-toast";
import DToastInstance from "float-kit/lib/d-toast-instance";

const TOAST_SELECTOR = ".fk-d-toast";

function createCustomToastInstance(owner, options, newClose) {
  const custom = class CustomToastInstance extends DToastInstance {
    constructor() {
      super(owner, options);
    }

    @action
    close() {
      newClose.apply(this);
    }
  };

  return new custom(owner, options);
}

module("Integration | Component | FloatKit | d-toast", function (hooks) {
  setupRenderingTest(hooks);

  test("swipe up to close", async function (assert) {
    let closing = false;
    this.site.mobileView = true;
    const toast = createCustomToastInstance(getOwner(this), {}, () => {
      closing = true;
    });

    await render(<template><DToast @toast={{toast}} /></template>);

    assert.dom(TOAST_SELECTOR).exists();

    await triggerEvent(TOAST_SELECTOR, "touchstart", {
      touches: [{ clientX: 0, clientY: 0 }],
      changedTouches: [{ clientX: 0, clientY: 0 }],
    });

    await triggerEvent(TOAST_SELECTOR, "touchmove", {
      touches: [{ clientX: 0, clientY: -100 }],
      changedTouches: [{ clientX: 0, clientY: -100 }],
    });

    await triggerEvent(TOAST_SELECTOR, "touchend", {
      touches: [{ clientX: 0, clientY: -100 }],
      changedTouches: [{ clientX: 0, clientY: -100 }],
    });

    assert.ok(closing);
  });
});
