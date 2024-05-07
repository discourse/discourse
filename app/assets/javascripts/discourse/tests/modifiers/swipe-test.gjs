import { getOwner } from "@ember/application";
import { clearRender, render, triggerEvent } from "@ember/test-helpers";
import { setupRenderingTest } from "ember-qunit";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";

module("Integration | Modifier | swipe", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    getOwner(this).lookup("service:site").mobileView = true;
  });

  async function swipe() {
    await triggerEvent("div", "touchstart", {
      changedTouches: [{ screenX: 0, screenY: 0 }],
      touches: [{ clientX: 0, clientY: 0 }],
    });
    await triggerEvent("div", "touchmove", {
      changedTouches: [{ screenX: 2, screenY: 2 }],
      touches: [{ clientX: 2, clientY: 2 }],
    });
    await triggerEvent("div", "touchmove", {
      changedTouches: [{ screenX: 4, screenY: 4 }],
      touches: [{ clientX: 4, clientY: 4 }],
    });
    await triggerEvent("div", "touchmove", {
      changedTouches: [{ screenX: 7, screenY: 7 }],
      touches: [{ clientX: 7, clientY: 7 }],
    });
    await triggerEvent("div", "touchmove", {
      changedTouches: [{ screenX: 9, screenY: 9 }],
      touches: [{ clientX: 9, clientY: 9 }],
    });
    await triggerEvent("div", "touchend", {
      changedTouches: [{ screenX: 10, screenY: 10 }],
      touches: [{ clientX: 10, clientY: 10 }],
    });
  }

  test("it calls onDidStartSwipe on touchstart", async function (assert) {
    const done = assert.async();
    this.didStartSwipe = (state) => {
      assert.ok(state, "didStartSwipe called with state");
      done();
    };

    await render(
      hbs`<div {{swipe onDidStartSwipe=this.didStartSwipe}}>x</div>`
    );

    await swipe();
  });

  test("it calls didSwipe on touchmove", async function (assert) {
    const done = assert.async();
    this.didSwipe = (state) => {
      assert.ok(state, "didSwipe called with state");
      done();
    };

    await render(hbs`<div {{swipe onDidSwipe=this.didSwipe}}>x</div>`);

    await swipe();
  });

  test("it calls didEndSwipe on touchend", async function (assert) {
    const done = assert.async();
    this.didEndSwipe = (state) => {
      assert.ok(state, "didEndSwipe called with state");
      done();
    };

    await render(hbs`<div {{swipe onDidEndSwipe=this.didEndSwipe}}>x</div>`);

    await swipe();
  });

  test("it does not trigger when disabled", async function (assert) {
    let calls = 0;

    this.didStartSwipe1 = () => {
      calls++;
    };

    this.set("isEnabled", false);

    await render(
      hbs`<div {{swipe onDidStartSwipe=this.didStartSwipe1 enabled=this.isEnabled}}>x</div>`
    );

    await swipe();

    assert.deepEqual(calls, 0, "swipe is disabled");

    await clearRender();

    this.set("isEnabled", true);
    const done = assert.async();
    this.didStartSwipe2 = () => {
      calls++;
      done();
    };

    await render(
      hbs`<div {{swipe onDidStartSwipe=this.didStartSwipe2 enabled=this.isEnabled}}>x</div>`
    );

    await swipe();

    assert.deepEqual(calls, 1, "swipe is enabled");

    await clearRender();

    this.didStartSwipe3 = () => {
      calls++;
    };
    getOwner(this).lookup("service:site").mobileView = false;

    await render(
      hbs`<div {{swipe onDidStartSwipe=this.didStartSwipe3 enabled=this.isEnabled}}>x</div>`
    );

    await swipe();

    assert.deepEqual(calls, 1, "swipe is not enabled on desktop");
  });
});
