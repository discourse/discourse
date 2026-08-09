import { track, validateTag, valueForTag } from "@glimmer/validator";
import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import ScrollController from "discourse/float-kit/components/d-scroll/controller";
import { prefersReducedMotion } from "discourse/lib/utilities";

module("Unit | FloatKit | d-scroll controller", function (hooks) {
  setupTest(hooks);

  test("starts with Silk's optimistic overflow state", function (assert) {
    const controller = new ScrollController();

    assert.true(controller.overflowX, "x overflow starts enabled");
    assert.true(controller.overflowY, "y overflow starts enabled");

    controller.cleanup();
  });

  test("same scroll state does not dirty tracked consumers", function (assert) {
    const controller = new ScrollController();
    let tag = track(() => controller.scrollOngoing);
    let snapshot = valueForTag(tag);

    controller.setScrollOngoing(false);

    assert.true(
      validateTag(tag, snapshot),
      "repeating the inactive state preserves the tracked tag"
    );

    controller.setScrollOngoing(true);

    assert.false(
      validateTag(tag, snapshot),
      "starting a scroll session dirties the tracked tag"
    );

    tag = track(() => controller.scrollOngoing);
    snapshot = valueForTag(tag);
    controller.setScrollOngoing(true);

    assert.true(
      validateTag(tag, snapshot),
      "repeating the active state preserves the tracked tag"
    );

    controller.cleanup();
  });

  test("overflow updates only dirty changed axes", async function (assert) {
    const controller = new ScrollController();
    const view = {
      clientHeight: 100,
      clientWidth: 100,
      scrollHeight: 200,
      scrollWidth: 200,
    };

    controller.registerView(view);
    await settled();

    assert.false(
      controller.overflowX,
      "the inactive x axis is not overflowing"
    );
    assert.true(controller.overflowY, "the active y axis is overflowing");

    let tag = track(() => controller.overflowY);
    let snapshot = valueForTag(tag);
    controller.updateOverflowState();

    assert.true(
      validateTag(tag, snapshot),
      "unchanged y dimensions preserve the tracked tag"
    );

    controller.configure({ axis: "x" });
    await settled();

    assert.true(controller.overflowX, "the new active x axis is overflowing");
    assert.false(controller.overflowY, "the inactive y axis is reset");

    tag = track(() => [controller.overflowX, controller.overflowY]);
    snapshot = valueForTag(tag);
    controller.updateOverflowState();

    assert.true(
      validateTag(tag, snapshot),
      "unchanged x dimensions preserve both tracked tags"
    );

    controller.cleanup();
  });

  test("scroll animation settings preserve the default and automatic modes", function (assert) {
    const calls = [];
    const controller = new ScrollController();
    controller.registerView({
      scrollTo: (options) => calls.push(options),
    });

    controller.scrollTo({ distance: 10 });
    controller.scrollTo({ distance: 20, animationSettings: {} });
    controller.scrollTo({ distance: 30, animationSettings: null });

    const automaticBehavior = prefersReducedMotion() ? "instant" : "smooth";
    assert.deepEqual(
      calls,
      [
        { top: 10, behavior: "auto" },
        { top: 20, behavior: automaticBehavior },
        { top: 30, behavior: automaticBehavior },
      ],
      "omitted settings use CSS defaults while empty settings use automatic motion"
    );

    controller.cleanup();
  });

  test("invalid imperative scroll distances are ignored", function (assert) {
    const calls = [];
    const controller = new ScrollController();
    controller.registerView({
      scrollBy: (options) => calls.push(["by", options]),
      scrollTo: (options) => calls.push(["to", options]),
    });

    controller.scrollTo({ progress: null });
    controller.scrollTo({ distance: "invalid" });
    controller.scrollBy({ progress: null });
    controller.scrollBy({ distance: "invalid" });

    assert.deepEqual(calls, [], "no invalid call reaches the scroll target");
    controller.cleanup();
  });

  test("cleanup cancels a pending overflow measurement", async function (assert) {
    const controller = new ScrollController();
    let layoutRead = false;
    const view = {
      get scrollWidth() {
        layoutRead = true;
        return 0;
      },
    };

    controller.registerView(view);
    controller.cleanup();
    await settled();

    assert.false(
      layoutRead,
      "the destroyed controller performs no deferred layout read"
    );
  });
});
