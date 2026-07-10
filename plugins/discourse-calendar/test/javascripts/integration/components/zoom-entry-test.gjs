import { getOwner } from "@ember/owner";
import { clearRender, click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import LivestreamZoomEntry, {
  MAX_RETRY_ATTEMPTS,
  RETRY_DELAY_SECONDS,
} from "../../discourse/components/livestream/zoom-entry";

const MEETING_NOT_STARTED = {
  errorCode: 3008,
  reason: "Meeting has not started",
};

const WAITING_SELECTOR = ".discourse-calendar-livestream-zoom-entry__waiting";
const ERROR_SELECTOR = ".discourse-calendar-livestream-zoom-entry__error";
const FRAME_SELECTOR = ".discourse-calendar-livestream-zoom-entry__frame";
const JOIN_BUTTON_SELECTOR =
  ".discourse-calendar-livestream-zoom-entry .btn-primary";
const LEAVE_BUTTON_SELECTOR = ".zoom-MuiButton-root";

const COUNTDOWN_TEXT = `The webinar hasn't started yet. Retrying join in ${RETRY_DELAY_SECONDS} seconds...`;
const ERROR_TEXT =
  "You left the webinar or we are unable to load Zoom in this page.";

// `joinZoom` guards against being called when the button is disabled, which a
// test can never reach through a click. `syncZoomLayout` runs from the modifier
// on insert, so stubbing it hands us the component instance before any join.
function captureComponent() {
  const captured = {};

  sinon
    .stub(LivestreamZoomEntry.prototype, "syncZoomLayout")
    .callsFake(function () {
      captured.component = this;
    });

  return captured;
}

function deferred() {
  let resolve, reject;
  const promise = new Promise((res, rej) => {
    resolve = res;
    reject = rej;
  });
  return { promise, resolve, reject };
}

// Zoom renders its own leave button inside the app root, both on the
// "meeting has not started" panel and on the joined toolbar. The component can
// only tell them apart by its own `isJoined` state, so both look like this.
// The inner span stands in for Zoom's icon, and makes sure we still match when
// the click lands on a descendant rather than the button itself.
function renderZoomLeaveButton() {
  const frame = document.querySelector(FRAME_SELECTOR);
  frame.innerHTML = `<button class="zoom-MuiButton-root" title="Leave"><span class="zoom-icon"></span></button>`;
}

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

  // Stands in for the real API service, mirroring the parts of `joinEvent` and
  // `updateEventAttendance` the component depends on: both leave the event
  // carrying a `watchingInvitee` with the new status.
  function stubEventApi(owner) {
    const api = {
      joinEvent: sinon.fake(function (event, payload) {
        event.watchingInvitee = { id: 5, status: payload.status };
        return Promise.resolve(event.watchingInvitee);
      }),
      updateEventAttendance: sinon.fake(function (event, payload) {
        event.watchingInvitee = { ...event.watchingInvitee, ...payload };
        return Promise.resolve(event.watchingInvitee);
      }),
    };

    owner.unregister("service:discourse-post-event-api");
    owner.register("service:discourse-post-event-api", api, {
      instantiate: false,
    });

    return api;
  }

  hooks.beforeEach(function () {
    const siteSettings = getOwner(this).lookup("service:site-settings");
    siteSettings.livestream_zoom_enabled = true;

    this.eventApi = stubEventApi(getOwner(this));

    this.event = {
      id: 42,
      currentlyWithinEventTimeframe: true,
      canUpdateAttendance: true,
      watchingInvitee: null,
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
    assert.dom(FRAME_SELECTOR).exists();
    assert
      .dom(`${FRAME_SELECTOR}.--visible`)
      .doesNotExist("the frame is hidden until the user joins");
    assert
      .dom(".discourse-calendar-livestream-zoom-entry a")
      .doesNotExist("no fallback link before an error");
  });

  test("renders the mobile route link on mobile", async function (assert) {
    stubCapabilities(getOwner(this), { lg: false });

    await render(
      <template><LivestreamZoomEntry @event={{this.event}} /></template>
    );

    assert.dom(JOIN_BUTTON_SELECTOR).hasText("Join Zoom");
    assert
      .dom(FRAME_SELECTOR)
      .doesNotExist("does not render the inline Zoom frame");
  });

  test("disables the join button outside the event timeframe", async function (assert) {
    stubCapabilities(getOwner(this), { lg: true });
    this.event.currentlyWithinEventTimeframe = false;

    await render(
      <template><LivestreamZoomEntry @event={{this.event}} /></template>
    );

    assert.dom(JOIN_BUTTON_SELECTOR).isDisabled();
    assert
      .dom(WAITING_SELECTOR)
      .hasText("You can join the webinar closer to the event start time");
  });

  test("disables the mobile join button outside the event timeframe", async function (assert) {
    stubCapabilities(getOwner(this), { lg: false });
    this.event.currentlyWithinEventTimeframe = false;

    await render(
      <template><LivestreamZoomEntry @event={{this.event}} /></template>
    );

    assert.dom(JOIN_BUTTON_SELECTOR).isDisabled();
    assert
      .dom(WAITING_SELECTOR)
      .hasText("You can join the webinar closer to the event start time");
  });

  test("renders nothing once the event is past its grace period", async function (assert) {
    stubCapabilities(getOwner(this), { lg: true });
    this.event.currentlyWithinEventTimeframe = false;
    this.event.pastEventTimeframe = true;

    await render(
      <template><LivestreamZoomEntry @event={{this.event}} /></template>
    );

    assert.dom(".discourse-calendar-livestream-zoom-entry").doesNotExist();
  });

  test("renders nothing when Zoom livestreams are disabled", async function (assert) {
    stubCapabilities(getOwner(this), { lg: true });
    getOwner(this).lookup("service:site-settings").livestream_zoom_enabled =
      false;

    await render(
      <template><LivestreamZoomEntry @event={{this.event}} /></template>
    );

    assert.dom(".discourse-calendar-livestream-zoom-entry").doesNotExist();
  });

  test("renders nothing without a livestream chat channel", async function (assert) {
    stubCapabilities(getOwner(this), { lg: true });
    this.event.livestreamChatChannelId = null;

    await render(
      <template><LivestreamZoomEntry @event={{this.event}} /></template>
    );

    assert.dom(".discourse-calendar-livestream-zoom-entry").doesNotExist();
  });

  test("renders nothing for anonymous users", async function (assert) {
    stubCapabilities(getOwner(this), { lg: true });
    getOwner(this).unregister("service:current-user");

    await render(
      <template><LivestreamZoomEntry @event={{this.event}} /></template>
    );

    assert.dom(".discourse-calendar-livestream-zoom-entry").doesNotExist();
  });

  module("when marking attendance", function (innerHooks) {
    let appEvents, performJoin;

    innerHooks.beforeEach(function () {
      stubCapabilities(getOwner(this), { lg: true });
      performJoin = sinon.stub(LivestreamZoomEntry.prototype, "performJoin");
      performJoin.resolves();
      appEvents = sinon.stub(
        getOwner(this).lookup("service:app-events"),
        "trigger"
      );
      sinon.stub(console, "error");
    });

    test("marks a user who has not answered as going", async function (assert) {
      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      await click(JOIN_BUTTON_SELECTOR);

      assert.strictEqual(this.eventApi.joinEvent.callCount, 1);
      assert.deepEqual(this.eventApi.joinEvent.firstCall.args[1], {
        status: "going",
      });
      assert.true(
        appEvents.calledWith("calendar:create-invitee-status", {
          status: "going",
          postId: 42,
        }),
        "tells the rest of the page the RSVP changed"
      );
      assert.dom(`${FRAME_SELECTOR}.--joined`).exists("still joins Zoom");
    });

    test("marks an invitee with no status as going", async function (assert) {
      this.event.watchingInvitee = { id: 5, status: null };

      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      await click(JOIN_BUTTON_SELECTOR);

      assert.false(
        this.eventApi.joinEvent.called,
        "does not re-join the event"
      );
      assert.strictEqual(this.eventApi.updateEventAttendance.callCount, 1);
      assert.deepEqual(this.eventApi.updateEventAttendance.firstCall.args[1], {
        status: "going",
      });
      assert.true(
        appEvents.calledWith("calendar:update-invitee-status", {
          status: "going",
          postId: 42,
        })
      );
    });

    test("leaves an existing answer alone", async function (assert) {
      this.event.watchingInvitee = { id: 5, status: "not_going" };

      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      await click(JOIN_BUTTON_SELECTOR);

      assert.false(this.eventApi.joinEvent.called);
      assert.false(
        this.eventApi.updateEventAttendance.called,
        "an explicit 'not going' is not overwritten"
      );
      assert.dom(`${FRAME_SELECTOR}.--joined`).exists("still joins Zoom");
    });

    test("leaves an existing 'going' answer alone", async function (assert) {
      this.event.watchingInvitee = { id: 5, status: "going", recurring: true };

      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      await click(JOIN_BUTTON_SELECTOR);

      assert.false(
        this.eventApi.updateEventAttendance.called,
        "does not clobber a recurring RSVP"
      );
    });

    test("does not RSVP when the user may not update attendance", async function (assert) {
      this.event.canUpdateAttendance = false;

      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      await click(JOIN_BUTTON_SELECTOR);

      assert.false(this.eventApi.joinEvent.called);
      assert.dom(`${FRAME_SELECTOR}.--joined`).exists("still joins Zoom");
    });

    test("joins Zoom even when the RSVP fails", async function (assert) {
      this.eventApi.joinEvent = sinon.fake.rejects(new Error("nope"));

      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      await click(JOIN_BUTTON_SELECTOR);

      assert.dom(`${FRAME_SELECTOR}.--joined`).exists("still joins Zoom");
      assert.dom(ERROR_SELECTOR).doesNotExist("does not surface an error");
    });

    test("only RSVPs once when the join is retried", async function (assert) {
      const clock = sinon.useFakeTimers({
        toFake: ["setInterval", "clearInterval"],
      });

      try {
        performJoin.rejects(MEETING_NOT_STARTED);

        await render(
          <template><LivestreamZoomEntry @event={{this.event}} /></template>
        );

        await click(JOIN_BUTTON_SELECTOR);

        performJoin.resolves();
        clock.tick(RETRY_DELAY_SECONDS * 1000);
        await settled();

        assert.dom(`${FRAME_SELECTOR}.--joined`).exists();
        assert.strictEqual(
          this.eventApi.joinEvent.callCount,
          1,
          "the retry sees the RSVP it already made"
        );
      } finally {
        clock.restore();
      }
    });
  });

  module("when joining", function (innerHooks) {
    let performJoin;

    innerHooks.beforeEach(function () {
      stubCapabilities(getOwner(this), { lg: true });
      performJoin = sinon.stub(LivestreamZoomEntry.prototype, "performJoin");
      sinon.stub(console, "error");
    });

    test("shows the Zoom frame and joins", async function (assert) {
      performJoin.resolves();

      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      await click(JOIN_BUTTON_SELECTOR);

      assert.true(performJoin.calledOnce);
      assert.dom(`${FRAME_SELECTOR}.--visible.--joined`).exists();
      assert.dom(JOIN_BUTTON_SELECTOR).doesNotExist("hides the join button");
      assert.dom(ERROR_SELECTOR).doesNotExist();
    });

    test("ignores a second click while a join is in flight", async function (assert) {
      const join = deferred();
      performJoin.returns(join.promise);

      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      // Not awaited: the join is deliberately left pending.
      click(JOIN_BUTTON_SELECTOR);
      await settled();

      assert.dom(JOIN_BUTTON_SELECTOR).isDisabled("disabled while joining");

      join.resolve();
      await settled();

      assert.true(performJoin.calledOnce, "only joined once");
    });

    test("does not join outside the event timeframe", async function (assert) {
      performJoin.resolves();
      this.event.currentlyWithinEventTimeframe = false;
      const captured = captureComponent();

      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      assert.dom(JOIN_BUTTON_SELECTOR).isDisabled();

      await captured.component.joinZoom();

      assert.false(performJoin.called, "the guard refuses the join");
      assert.dom(`${FRAME_SELECTOR}.--visible`).doesNotExist();
    });

    test("shows an error and a fallback link when the join fails", async function (assert) {
      performJoin.rejects(new Error("nope"));

      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      await click(JOIN_BUTTON_SELECTOR);

      assert.dom(ERROR_SELECTOR).hasText(ERROR_TEXT);
      assert
        .dom(".discourse-calendar-livestream-zoom-entry a")
        .hasText("Open in Zoom", "offers the fallback link");
      assert.dom(`${FRAME_SELECTOR}.--visible`).doesNotExist();
      assert.dom(JOIN_BUTTON_SELECTOR).isNotDisabled("can be retried");
    });

    test("clears a previous error once a later join succeeds", async function (assert) {
      performJoin.rejects(new Error("nope"));

      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      await click(JOIN_BUTTON_SELECTOR);
      assert.dom(ERROR_SELECTOR).exists();

      performJoin.resolves();
      await click(JOIN_BUTTON_SELECTOR);

      assert.dom(ERROR_SELECTOR).doesNotExist("clears the error message");
      assert
        .dom(".discourse-calendar-livestream-zoom-entry a")
        .doesNotExist("clears the fallback link");
      assert.dom(`${FRAME_SELECTOR}.--joined`).exists();
    });

    test("leaving a joined meeting is left to Zoom's confirmation dialog", async function (assert) {
      performJoin.resolves();

      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      await click(JOIN_BUTTON_SELECTOR);
      renderZoomLeaveButton();

      // Zoom's toolbar leave button only opens a confirmation popper. Tearing
      // the frame down here would strand the user in an invisible meeting.
      await click(LEAVE_BUTTON_SELECTOR);

      assert.dom(`${FRAME_SELECTOR}.--joined`).exists("keeps the frame up");
      assert.dom(JOIN_BUTTON_SELECTOR).doesNotExist("stays joined");
    });

    test("hides the frame when the meeting closes", async function (assert) {
      let component;
      performJoin.callsFake(function () {
        component = this;
        return Promise.resolve();
      });

      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      await click(JOIN_BUTTON_SELECTOR);
      document.querySelector(FRAME_SELECTOR).style.height = "600px";

      // What the `connection-change` handler does when the host ends the
      // meeting while the user is still on the page.
      component.leaveZoom();
      await settled();

      assert.dom(`${FRAME_SELECTOR}.--visible`).doesNotExist("hides the frame");
      assert.dom(`${FRAME_SELECTOR}.--joined`).doesNotExist();
      assert.strictEqual(
        document.querySelector(FRAME_SELECTOR).style.height,
        "",
        "strips the inline height Zoom left behind, which would otherwise leave an empty box"
      );
      assert.dom(JOIN_BUTTON_SELECTOR).isNotDisabled("can join again");
    });
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
        .hasText(COUNTDOWN_TEXT, "shows the initial countdown");
      assert
        .dom(`${FRAME_SELECTOR}.--visible`)
        .exists("keeps the Zoom frame up while waiting");
      assert
        .dom(`${FRAME_SELECTOR}.--joined`)
        .doesNotExist("but not in its joined layout");

      await tick(1);

      assert
        .dom(WAITING_SELECTOR)
        .hasText(
          `The webinar hasn't started yet. Retrying join in ${
            RETRY_DELAY_SECONDS - 1
          } seconds...`,
          "the countdown updates every second"
        );

      performJoin.resetHistory();
      await tick(RETRY_DELAY_SECONDS - 1);

      assert.true(performJoin.calledOnce, "retries the join at zero");
      assert
        .dom(WAITING_SELECTOR)
        .hasText(
          COUNTDOWN_TEXT,
          "restarts the countdown after another failure"
        );
    });

    test("reports that a retry is in flight", async function (assert) {
      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      await click(JOIN_BUTTON_SELECTOR);

      const retry = deferred();
      performJoin.returns(retry.promise);
      await tick(RETRY_DELAY_SECONDS);

      assert
        .dom(WAITING_SELECTOR)
        .hasText(
          "Trying to join the webinar again now...",
          "swaps the countdown for the in-flight message"
        );

      retry.resolve();
      await settled();

      assert.dom(WAITING_SELECTOR).doesNotExist();
      assert.dom(`${FRAME_SELECTOR}.--joined`).exists();
    });

    test("joins when the meeting starts", async function (assert) {
      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      await click(JOIN_BUTTON_SELECTOR);

      performJoin.resolves();
      await tick(RETRY_DELAY_SECONDS);

      assert.dom(WAITING_SELECTOR).doesNotExist("clears the waiting message");
      assert.dom(JOIN_BUTTON_SELECTOR).doesNotExist("hides the join button");
      assert
        .dom(`${FRAME_SELECTOR}.--joined`)
        .exists("shows the joined Zoom frame");
    });

    test("stops retrying on a non-retryable error", async function (assert) {
      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      await click(JOIN_BUTTON_SELECTOR);

      performJoin.rejects(new Error("nope"));
      await tick(RETRY_DELAY_SECONDS);

      assert.dom(WAITING_SELECTOR).doesNotExist("stops the countdown");
      assert.dom(JOIN_BUTTON_SELECTOR).isNotDisabled();
      assert.dom(ERROR_SELECTOR).hasText(ERROR_TEXT);
      assert
        .dom(`${FRAME_SELECTOR}.--visible`)
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

      // The initial click is attempt 1, so MAX_RETRY_ATTEMPTS further attempts
      // exhaust the budget.
      for (let i = 0; i < MAX_RETRY_ATTEMPTS; i++) {
        await tick(RETRY_DELAY_SECONDS);
      }

      assert.dom(WAITING_SELECTOR).doesNotExist("stops the countdown");
      assert.dom(JOIN_BUTTON_SELECTOR).isNotDisabled();
      assert.dom(ERROR_SELECTOR).hasText(ERROR_TEXT);
    });

    test("stops retrying when the user leaves Zoom's not-started panel", async function (assert) {
      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      await click(JOIN_BUTTON_SELECTOR);
      renderZoomLeaveButton();

      // Zoom fires no `connection-change` event from this panel, so the click
      // itself is the only signal that the user wants out.
      await click(LEAVE_BUTTON_SELECTOR);

      assert.dom(WAITING_SELECTOR).doesNotExist("stops the countdown");
      assert.dom(`${FRAME_SELECTOR}.--visible`).doesNotExist("hides the frame");
      assert.dom(JOIN_BUTTON_SELECTOR).isNotDisabled("re-enables joining");

      performJoin.resetHistory();
      await tick(RETRY_DELAY_SECONDS * 2);

      assert.false(performJoin.called, "does not retry after leaving");
    });

    test("can join again after leaving the not-started panel", async function (assert) {
      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      await click(JOIN_BUTTON_SELECTOR);
      renderZoomLeaveButton();
      await click(LEAVE_BUTTON_SELECTOR);

      performJoin.resolves();
      await click(JOIN_BUTTON_SELECTOR);

      assert.dom(`${FRAME_SELECTOR}.--joined`).exists("joins on a fresh click");
    });

    test("stops retrying once the component is torn down", async function (assert) {
      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      await click(JOIN_BUTTON_SELECTOR);
      await clearRender();

      performJoin.resetHistory();
      await tick(RETRY_DELAY_SECONDS * 2);

      assert.false(
        performJoin.called,
        "the retry timer does not outlive the component"
      );
    });
  });
});
