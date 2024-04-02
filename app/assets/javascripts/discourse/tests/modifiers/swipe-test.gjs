import { render, triggerEvent } from "@ember/test-helpers";
import { setupRenderingTest } from "ember-qunit";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";

module("Integration | Modifier | swipe", function (hooks) {
  setupRenderingTest(hooks);

  test("it calls didStartSwipe on touchstart", async function (assert) {
    this.didStartSwipe = (state) => {
      assert.ok(state, "didStartSwipe called with state");
    };

    await render(hbs`<div {{swipe didStartSwipe=this.didStartSwipe}}></div>`);

    await triggerEvent("div", "touchstart", {
      touches: [{ clientX: 0, clientY: 0 }],
    });
  });

  test("it calls didSwipe on touchmove", async function (assert) {
    this.didSwipe = (state) => {
      assert.ok(state, "didSwipe called with state");
    };

    await render(hbs`<div {{swipe didSwipe=this.didSwipe}}></div>`);

    await triggerEvent("div", "touchstart", {
      touches: [{ clientX: 0, clientY: 0 }],
      changedTouches: [{ clientX: 0, clientY: 0 }],
    });

    await triggerEvent("div", "touchmove", {
      touches: [{ clientX: 5, clientY: 5 }],
    });
  });

  test("it calls didEndSwipe on touchend", async function (assert) {
    this.didEndSwipe = (state) => {
      assert.ok(state, "didEndSwipe called with state");
    };

    await render(hbs`<div {{swipe didEndSwipe=this.didEndSwipe}}></div>`);

    await triggerEvent("div", "touchstart", {
      touches: [{ clientX: 0, clientY: 0 }],
      changedTouches: [{ clientX: 0, clientY: 0 }],
    });

    await triggerEvent("div", "touchmove", {
      touches: [{ clientX: 10, clientY: 0 }],
      changedTouches: [{ clientX: 10, clientY: 0 }],
    });

    await triggerEvent("div", "touchend", {
      changedTouches: [{ clientX: 10, clientY: 0 }],
    });
  });

  test("it does not trigger when disabled", async function (assert) {
    let calls = 0;

    this.didStartSwipe = () => {
      calls++;
    };

    this.set("isEnabled", false);

    await render(
      hbs`<div {{swipe didStartSwipe=this.didStartSwipe enabled=this.isEnabled}}></div>`
    );

    await triggerEvent("div", "touchstart", {
      touches: [{ clientX: 0, clientY: 0 }],
    });

    this.set("isEnabled", true);

    await triggerEvent("div", "touchstart", {
      touches: [{ clientX: 0, clientY: 0 }],
    });

    assert.deepEqual(calls, 1, "didStartSwipe should be called once");
  });
});
