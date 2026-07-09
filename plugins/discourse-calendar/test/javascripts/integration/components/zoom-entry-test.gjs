import { getOwner } from "@ember/owner";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import LivestreamZoomEntry from "../../discourse/components/livestream/zoom-entry";

const MEETING_NOT_STARTED = {
  errorCode: 3008,
  reason: "Meeting has not started",
};

const WAITING_SELECTOR = ".discourse-calendar-livestream-zoom-entry__waiting";
const ERROR_SELECTOR = ".discourse-calendar-livestream-zoom-entry__error";
const JOIN_BUTTON_SELECTOR =
  ".discourse-calendar-livestream-zoom-entry .btn-primary";

module("Integration | Component | LivestreamZoomEntry", function (hooks) {
  setupRenderingTest(hooks);

  function stubCapabilities(owner, viewport) {
    owner.unregister("service:capabilities");
    owner.register(
      "service:capabilities",
      {
        viewport,
      },
      { instantiate: false }
    );
  }

  hooks.beforeEach(function () {
    const siteSettings = getOwner(this).lookup("service:site-settings");
    siteSettings.livestream_zoom_enabled = true;

    this.event = {
      currentlyWithinEventTimeframe: true,
      livestreamChatChannelId: 9,
      post: {
        topic: {
          id: 1,
          slug: "test-topic",
          chat_channel_id: 9,
        },
      },
      url: "https://us06web.zoom.us/j/123456789?pwd=secret",
      livestreamUrl: "https://us06web.zoom.us/j/123456789?pwd=secret",
    };
  });

  test("renders the inline join button on desktop", async function (assert) {
    stubCapabilities(getOwner(this), { lg: true });

    await render(
      <template><LivestreamZoomEntry @event={{this.event}} /></template>
    );

    assert.dom(JOIN_BUTTON_SELECTOR).hasText("Join Zoom");
    assert.dom(".discourse-calendar-livestream-zoom-entry__frame").exists();
  });

  test("renders the mobile route link on mobile", async function (assert) {
    stubCapabilities(getOwner(this), { lg: false });

    await render(
      <template><LivestreamZoomEntry @event={{this.event}} /></template>
    );

    assert.dom(JOIN_BUTTON_SELECTOR).hasText("Join Zoom");
    assert
      .dom(".discourse-calendar-livestream-zoom-entry__frame")
      .doesNotExist("does not render the inline Zoom frame");
  });

  module("when the meeting has not started", function (innerHooks) {
    let clock, performJoin;

    innerHooks.beforeEach(function () {
      stubCapabilities(getOwner(this), { lg: true });

      // Only the countdown timers are faked, so `settled()` still works.
      clock = sinon.useFakeTimers({ toFake: ["setInterval", "clearInterval"] });

      performJoin = sinon.stub(LivestreamZoomEntry.prototype, "performJoin");
      performJoin.rejects(MEETING_NOT_STARTED);

      sinon.stub(console, "error");
    });

    innerHooks.afterEach(function () {
      clock.restore();
    });

    async function tick(seconds) {
      clock.tick(seconds * 1000);
      await settled();
    }

    test("counts down and retries the join", async function (assert) {
      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      await click(JOIN_BUTTON_SELECTOR);

      assert.dom(JOIN_BUTTON_SELECTOR).isDisabled();
      assert
        .dom(WAITING_SELECTOR)
        .hasText(
          "The meeting hasn't started yet. Retrying join in 30 seconds…",
          "shows the initial countdown"
        );
      assert
        .dom(".discourse-calendar-livestream-zoom-entry__frame.--visible")
        .exists("keeps the Zoom frame up while waiting");
      assert
        .dom(".discourse-calendar-livestream-zoom-entry__frame.--joined")
        .doesNotExist("but not in its joined layout");

      await tick(1);

      assert
        .dom(WAITING_SELECTOR)
        .hasText(
          "The meeting hasn't started yet. Retrying join in 29 seconds…",
          "the countdown updates every second"
        );

      performJoin.resetHistory();
      await tick(29);

      assert.true(performJoin.calledOnce, "retries the join at zero");
      assert
        .dom(WAITING_SELECTOR)
        .hasText(
          "The meeting hasn't started yet. Retrying join in 30 seconds…",
          "restarts the countdown after another failure"
        );
    });

    test("joins when the meeting starts", async function (assert) {
      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      await click(JOIN_BUTTON_SELECTOR);

      performJoin.resolves();
      await tick(30);

      assert.dom(WAITING_SELECTOR).doesNotExist("clears the waiting message");
      assert.dom(JOIN_BUTTON_SELECTOR).doesNotExist("hides the join button");
      assert
        .dom(".discourse-calendar-livestream-zoom-entry__frame.--joined")
        .exists("shows the joined Zoom frame");
    });

    test("stops retrying on a non-retryable error", async function (assert) {
      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      await click(JOIN_BUTTON_SELECTOR);

      performJoin.rejects(new Error("nope"));
      await tick(30);

      assert.dom(WAITING_SELECTOR).doesNotExist("stops the countdown");
      assert.dom(JOIN_BUTTON_SELECTOR).isNotDisabled();
      assert.dom(ERROR_SELECTOR).hasText("Unable to load Zoom in this page.");
      assert
        .dom(".discourse-calendar-livestream-zoom-entry__frame.--visible")
        .doesNotExist("tears the Zoom frame down");
      assert
        .dom(".discourse-calendar-livestream-zoom-entry a")
        .hasText("Open in Zoom", "offers the fallback link");
    });

    test("gives up once the retry budget is exhausted", async function (assert) {
      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      await click(JOIN_BUTTON_SELECTOR);

      // The initial click is attempt 1, so 40 further attempts exhaust the budget.
      for (let i = 0; i < 40; i++) {
        await tick(30);
      }

      assert.dom(WAITING_SELECTOR).doesNotExist("stops the countdown");
      assert.dom(JOIN_BUTTON_SELECTOR).isNotDisabled();
      assert.dom(ERROR_SELECTOR).hasText("Unable to load Zoom in this page.");
    });
  });
});
