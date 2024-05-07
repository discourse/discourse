import { render, triggerEvent } from "@ember/test-helpers";
import { setupRenderingTest } from "ember-qunit";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";

module("Integration | Modifier | swipe", function (hooks) {
  setupRenderingTest(hooks);

  async function swipe() {
    await triggerEvent("div", "touchstart", {
      touches: [{ clientX: 0, clientY: 0 }],
    });
    await triggerEvent("div", "touchmove", {
      touches: [{ clientX: 1, clientY: 0 }],
    });
    await triggerEvent("div", "touchmove", {
      touches: [{ clientX: 5, clientY: 0 }],
    });
    await triggerEvent("div", "touchmove", {
      touches: [{ clientX: 10, clientY: 0 }],
    });
    await triggerEvent("div", "touchend", {
      touches: [{ clientX: 10, clientY: 0 }],
    });
  }

  test("it calls onDidStartSwipe on touchstart", async function (assert) {
    this.didStartSwipe = (state) => {
      assert.ok(state, "didStartSwipe called with state");
    };

    await render(
      hbs`<div {{swipe onDidStartSwipe=this.didStartSwipe}}>x</div>`
    );

    await swipe();
  });

  test("it calls didSwipe on touchmove", async function (assert) {
    this.didSwipe = (state) => {
      assert.ok(state, "didSwipe called with state");
    };

    await render(hbs`<div {{swipe onDidSwipe=this.didSwipe}}>x</div>`);

    await swipe();
  });

  test("it calls didEndSwipe on touchend", async function (assert) {
    this.didEndSwipe = (state) => {
      assert.ok(state, "didEndSwipe called with state");
    };

    await render(hbs`<div {{swipe onDidEndSwipe=this.didEndSwipe}}>x</div>`);

    await swipe();
  });

  test("it does not trigger when disabled", async function (assert) {
    let calls = 0;

    this.didStartSwipe = () => {
      calls++;
    };

    this.set("isEnabled", false);

    await render(
      hbs`<div {{swipe onDidStartSwipe=this.didStartSwipe enabled=this.isEnabled}}>x</div>`
    );

    await swipe();

    this.set("isEnabled", true);

    await swipe();

    assert.deepEqual(calls, 1, "didStartSwipe should be called once");
  });
});
