import { getOwner } from "@ember/owner";
import { clearRender, click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { publishToMessageBus } from "discourse/tests/helpers/qunit-helpers";
import LivestreamZoomEntry from "../../discourse/components/livestream/zoom-entry";
import ZoomMeetingSession, {
  MAX_RETRY_ATTEMPTS,
  resumeStorageKey,
  RETRY_DELAY_SECONDS,
} from "../../discourse/lib/zoom-meeting-session";

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
const STOP_WAITING_SELECTOR =
  ".discourse-calendar-livestream-zoom-entry__stop-waiting";
const AUDIO_HINT_SELECTOR =
  ".discourse-calendar-livestream-zoom-entry__audio-hint";

const COUNTDOWN_TEXT = `The webinar hasn't started yet. Retrying join in ${RETRY_DELAY_SECONDS} seconds...`;
const ERROR_TEXT =
  "You left the webinar or we are unable to load Zoom in this page.";

// `join` guards against being called when the button is disabled, which a
// test can never reach through a click. `registerRoot` runs from the modifier
// on insert, so stubbing it hands us the session instance before any join.
function captureSession() {
  const captured = {};

  const stub = sinon
    .stub(ZoomMeetingSession.prototype, "registerRoot")
    .callsFake(function (element) {
      captured.session = this;
      stub.wrappedMethod.call(this, element);
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

// Stands in for the client the real `performJoin` creates, which the stubbed
// one never does.
function stubMountedZoomClient(session) {
  const client = {
    leaveMeeting: sinon.fake.resolves(),
    updateVideoOptions: sinon.fake(),
  };

  session.zoomClient = client;
  session.sdkInitialized = true;

  return { client };
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

    // Retrying reloads the page, which would take the test run with it.
    this.reloadPage = sinon.stub(ZoomMeetingSession.prototype, "reloadPage");
    window.sessionStorage.removeItem(resumeStorageKey(1));

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

  test("renders button for anonymous users", async function (assert) {
    stubCapabilities(getOwner(this), { lg: true });
    getOwner(this).unregister("service:current-user");

    await render(
      <template><LivestreamZoomEntry @event={{this.event}} /></template>
    );

    assert.dom(".discourse-calendar-livestream-zoom-entry").exists();
  });

  test("shows the audio hint only once the meeting is joined", async function (assert) {
    stubCapabilities(getOwner(this), { lg: true });
    const performJoin = sinon.stub(ZoomMeetingSession.prototype, "performJoin");
    const join = deferred();
    performJoin.returns(join.promise);

    await render(
      <template><LivestreamZoomEntry @event={{this.event}} /></template>
    );

    assert.dom(AUDIO_HINT_SELECTOR).doesNotExist("hidden before joining");

    click(JOIN_BUTTON_SELECTOR);
    await settled();

    assert.dom(AUDIO_HINT_SELECTOR).doesNotExist("hidden while joining");

    join.resolve();
    await settled();

    assert.dom(AUDIO_HINT_SELECTOR).hasText("Click above to join audio");
    assert.dom(`${AUDIO_HINT_SELECTOR} .d-icon-zoom-join-audio`).exists();
  });

  test("hides the audio hint once the user connects audio", async function (assert) {
    stubCapabilities(getOwner(this), { lg: true });
    const captured = captureSession();
    sinon.stub(ZoomMeetingSession.prototype, "performJoin").resolves();

    await render(
      <template><LivestreamZoomEntry @event={{this.event}} /></template>
    );

    await click(JOIN_BUTTON_SELECTOR);

    const { session } = captured;
    session.zoomClient = {
      getCurrentUser: () => ({ userId: 1, audio: "" }),
      updateVideoOptions: () => {},
    };

    session.syncAudioState();
    await settled();

    assert.dom(AUDIO_HINT_SELECTOR).exists("audio is not connected yet");

    session.zoomClient.getCurrentUser = () => ({
      userId: 1,
      audio: "computer",
    });
    session.syncAudioState();
    await settled();

    assert.dom(AUDIO_HINT_SELECTOR).doesNotExist();
  });

  module("when marking attendance", function (innerHooks) {
    let appEvents, performJoin;

    innerHooks.beforeEach(function () {
      stubCapabilities(getOwner(this), { lg: true });
      performJoin = sinon.stub(ZoomMeetingSession.prototype, "performJoin");
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

    test("does not RSVP again when the retry resumes", async function (assert) {
      window.sessionStorage.setItem(
        resumeStorageKey(1),
        JSON.stringify({ topicId: 1, attempts: 1, at: Date.now() })
      );
      this.event.watchingInvitee = { id: 5, status: "going" };

      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      assert.true(performJoin.called, "resumes the join after the reload");
      assert.false(
        this.eventApi.joinEvent.called,
        "the RSVP made before the reload still stands"
      );
      assert.false(this.eventApi.updateEventAttendance.called);
    });

    test("only RSVPs once before the retry reloads", async function (assert) {
      const clock = sinon.useFakeTimers({
        toFake: ["setInterval", "clearInterval"],
      });

      try {
        performJoin.rejects(MEETING_NOT_STARTED);

        await render(
          <template><LivestreamZoomEntry @event={{this.event}} /></template>
        );

        await click(JOIN_BUTTON_SELECTOR);

        clock.tick(RETRY_DELAY_SECONDS * 1000);
        await settled();

        assert.true(this.reloadPage.calledOnce, "reloads to retry");
        assert.strictEqual(
          this.eventApi.joinEvent.callCount,
          1,
          "RSVPs for the attempt that ran here, and no more"
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
      performJoin = sinon.stub(ZoomMeetingSession.prototype, "performJoin");
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
      const captured = captureSession();

      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      assert.dom(JOIN_BUTTON_SELECTOR).isDisabled();

      await captured.session.join();

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
      let session;
      performJoin.callsFake(function () {
        session = this;
        return Promise.resolve();
      });

      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      await click(JOIN_BUTTON_SELECTOR);
      document.querySelector(FRAME_SELECTOR).style.height = "600px";

      // What the `connection-change` handler does when the host ends the
      // meeting while the user is still on the page.
      session.leaveZoom();
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

    test("waits for the host rather than joining early when Zoom will tell us", async function (assert) {
      performJoin.resolves();
      this.event.livestreamStartIsPushed = true;
      this.event.livestreamStarted = false;

      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      await click(JOIN_BUTTON_SELECTOR);

      assert.false(
        performJoin.called,
        "a join before the host starts would leave the SDK unable to retry"
      );
      assert
        .dom(WAITING_SELECTOR)
        .hasText(
          "Waiting for the host to start the webinar. You'll join automatically."
        );
      assert.strictEqual(
        this.eventApi.joinEvent.callCount,
        1,
        "still RSVPs while waiting"
      );

      await publishToMessageBus(
        `/discourse-calendar/livestream/zoom/${this.event.post.topic.id}`,
        { live: true }
      );

      assert.true(performJoin.called, "joins as soon as the host starts");
      assert.dom(WAITING_SELECTOR).doesNotExist();
      assert.dom(`${FRAME_SELECTOR}.--joined`).exists();
    });

    test("retries rather than waiting once the start has been announced", async function (assert) {
      performJoin.rejects(MEETING_NOT_STARTED);
      this.event.livestreamStartIsPushed = true;
      this.event.livestreamStarted = true;

      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      await click(JOIN_BUTTON_SELECTOR);

      // Zoom announces a start once, so waiting for a second announcement
      // would be waiting forever — a webinar started into a practice session
      // keeps failing 3008 with no further webhook.
      assert
        .dom(WAITING_SELECTOR)
        .hasText(COUNTDOWN_TEXT, "hands the failure to the retry instead");
      assert
        .dom(STOP_WAITING_SELECTOR)
        .exists("and the retry is still cancellable");
    });

    test("offers a way out of waiting when the start signal never comes", async function (assert) {
      performJoin.resolves();
      this.event.livestreamStartIsPushed = true;
      this.event.livestreamStarted = false;

      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      await click(JOIN_BUTTON_SELECTOR);

      assert
        .dom(JOIN_BUTTON_SELECTOR)
        .doesNotExist("the join button gives way while waiting");

      // Zoom never reports a start for a webinar on another account, so the
      // wait cannot be the only way forward.
      await click(STOP_WAITING_SELECTOR);

      assert.false(performJoin.called, "stopping is not another join attempt");
      assert.dom(WAITING_SELECTOR).doesNotExist();
      assert
        .dom(JOIN_BUTTON_SELECTOR)
        .isNotDisabled("the user is back in charge");

      // Zoom never reports a start for a webinar on another account, so this
      // link is the only real way in.
      assert
        .dom(".discourse-calendar-livestream-zoom-entry a")
        .hasText("Open in Zoom");
    });

    test("joins straight away when the webinar is already live", async function (assert) {
      performJoin.resolves();
      this.event.livestreamStartIsPushed = true;
      this.event.livestreamStarted = true;

      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      await click(JOIN_BUTTON_SELECTOR);

      assert.true(performJoin.calledOnce, "does not wait to be told twice");
      assert.dom(`${FRAME_SELECTOR}.--joined`).exists();
    });

    test("reloads rather than initializing the SDK twice", async function (assert) {
      const captured = captureSession();
      performJoin.resolves();

      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      await click(JOIN_BUTTON_SELECTOR);

      // Stands in for the init the stubbed `performJoin` never ran.
      stubMountedZoomClient(captured.session);

      captured.session.leaveZoom();
      await settled();
      await click(JOIN_BUTTON_SELECTOR);

      assert.true(
        this.reloadPage.calledOnce,
        "the SDK cannot be initialized twice in one document"
      );
      assert.strictEqual(
        performJoin.callCount,
        1,
        "does not try to join again in this document"
      );
    });

    test("does not resize the video before the meeting is joined", async function (assert) {
      const captured = captureSession();
      const join = deferred();
      performJoin.returns(join.promise);

      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      await click(JOIN_BUTTON_SELECTOR);

      const { client } = stubMountedZoomClient(captured.session);

      // The frame resizes while Zoom is still connecting, and the SDK throws
      // from inside its own bundle if it is asked to resize that early.
      captured.session.syncVideoSize();

      assert.false(
        client.updateVideoOptions.called,
        "leaves the video alone until the media session is up"
      );

      join.resolve();
      await settled();
      client.updateVideoOptions.resetHistory();

      captured.session.syncVideoSize();

      assert.true(
        client.updateVideoOptions.calledOnce,
        "resizes once the meeting is joined"
      );
    });
  });

  module("when the meeting has not started", function (innerHooks) {
    let clock, performJoin, reloadPage;

    innerHooks.beforeEach(function () {
      stubCapabilities(getOwner(this), { lg: true });

      // Only the countdown timers are faked, so `settled()` still works.
      clock = sinon.useFakeTimers({ toFake: ["setInterval", "clearInterval"] });

      performJoin = sinon.stub(ZoomMeetingSession.prototype, "performJoin");
      performJoin.rejects(MEETING_NOT_STARTED);

      reloadPage = this.reloadPage;
      sinon.stub(console, "error");
    });

    innerHooks.afterEach(function () {
      clock.restore();
      window.sessionStorage.removeItem(resumeStorageKey(1));
    });

    function resumeState() {
      const raw = window.sessionStorage.getItem(resumeStorageKey(1));
      return raw ? JSON.parse(raw) : null;
    }

    async function tick(seconds) {
      clock.tick(seconds * 1000);
      await settled();
    }

    test("counts down and retries the join", async function (assert) {
      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      await click(JOIN_BUTTON_SELECTOR);

      // A countdown reloads the page on its own, so it always offers a way
      // out rather than a disabled button.
      assert.dom(JOIN_BUTTON_SELECTOR).doesNotExist();
      assert.dom(STOP_WAITING_SELECTOR).exists();
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

      // Zoom's SDK cannot be initialized twice in one document, so the retry
      // is a fresh page rather than another join here.
      assert.true(reloadPage.calledOnce, "reloads at zero");
      assert.false(performJoin.called, "does not join again in this document");
      assert.deepEqual(
        { topicId: resumeState().topicId, attempts: resumeState().attempts },
        { topicId: 1, attempts: 1 },
        "hands the attempt budget to the next page"
      );
    });

    test("does not put the user back to waiting once they stop waiting", async function (assert) {
      this.event.livestreamStartIsPushed = true;
      this.event.livestreamStarted = false;

      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      await click(JOIN_BUTTON_SELECTOR);
      await click(STOP_WAITING_SELECTOR);

      // Stopping has to actually stop: neither the waiting message nor a
      // countdown, which would just be a different wait.
      assert.dom(WAITING_SELECTOR).doesNotExist();
      assert.strictEqual(resumeState(), null, "nothing scheduled");
      assert.false(reloadPage.called);
      assert
        .dom(JOIN_BUTTON_SELECTOR)
        .isNotDisabled("hands the decision back to the user");
      assert
        .dom(".discourse-calendar-livestream-zoom-entry a")
        .hasText("Open in Zoom", "and offers a way in");
    });

    test("joining again after stopping goes back to waiting", async function (assert) {
      this.event.livestreamStartIsPushed = true;
      this.event.livestreamStarted = false;

      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      await click(JOIN_BUTTON_SELECTOR);
      await click(STOP_WAITING_SELECTOR);
      await click(JOIN_BUTTON_SELECTOR);

      assert
        .dom(WAITING_SELECTOR)
        .hasText(
          "Waiting for the host to start the webinar. You'll join automatically.",
          "clicking join is a fresh decision, not one an earlier stop can refuse"
        );
      assert.false(performJoin.called, "and still does not join early");
    });

    test("holds the reload until the tab is visible again", async function (assert) {
      const setVisibility = (state) =>
        Object.defineProperty(document, "visibilityState", {
          configurable: true,
          get: () => state,
        });

      setVisibility("hidden");

      try {
        await render(
          <template><LivestreamZoomEntry @event={{this.event}} /></template>
        );

        await click(JOIN_BUTTON_SELECTOR);
        await tick(RETRY_DELAY_SECONDS);

        assert.false(
          reloadPage.called,
          "reloading a tab nobody is looking at is pure churn"
        );
        assert.strictEqual(
          resumeState(),
          null,
          "the marker would be stale by the time anyone came back"
        );

        setVisibility("visible");
        document.dispatchEvent(new Event("visibilitychange"));
        await settled();

        assert.true(reloadPage.calledOnce, "reloads once the user returns");
        assert.strictEqual(
          resumeState().attempts,
          1,
          "and still spends the attempt it was holding"
        );
      } finally {
        delete document.visibilityState;
      }
    });

    test("resumes the join after the reload", async function (assert) {
      window.sessionStorage.setItem(
        resumeStorageKey(1),
        JSON.stringify({ topicId: 1, attempts: 3, at: Date.now() })
      );

      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      assert.true(
        performJoin.called,
        "joins without waiting for another click"
      );
      assert
        .dom(WAITING_SELECTOR)
        .hasText(COUNTDOWN_TEXT, "picks the countdown back up");
      assert.strictEqual(
        resumeState(),
        null,
        "consumes the marker so a later load does not join on its own"
      );
    });

    test("does not resume a marker left by another topic", async function (assert) {
      window.sessionStorage.setItem(
        resumeStorageKey(1),
        JSON.stringify({ topicId: 999, attempts: 1, at: Date.now() })
      );

      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      assert.false(performJoin.called);
      assert.dom(JOIN_BUTTON_SELECTOR).isNotDisabled();
    });

    test("stops the countdown when the event window closes", async function (assert) {
      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      await click(JOIN_BUTTON_SELECTOR);

      this.event.currentlyWithinEventTimeframe = false;
      await tick(RETRY_DELAY_SECONDS);

      assert.false(reloadPage.called, "does not reload to retry");
      assert.strictEqual(resumeState(), null, "leaves nothing to resume");
      assert
        .dom(`${FRAME_SELECTOR}.--visible`)
        .doesNotExist("tears the Zoom frame down");
      assert.dom(JOIN_BUTTON_SELECTOR).isDisabled();
    });

    test("does not retry a non-retryable error", async function (assert) {
      performJoin.rejects(new Error("nope"));

      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      await click(JOIN_BUTTON_SELECTOR);
      await tick(RETRY_DELAY_SECONDS);

      assert.false(reloadPage.called, "only 3008 is worth another page");
      assert.dom(WAITING_SELECTOR).doesNotExist("never starts a countdown");
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
      window.sessionStorage.setItem(
        resumeStorageKey(1),
        JSON.stringify({
          topicId: 1,
          attempts: MAX_RETRY_ATTEMPTS,
          at: Date.now(),
        })
      );

      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      assert.false(
        performJoin.called,
        "a webinar that never starts stops reloading the page"
      );
      assert.dom(WAITING_SELECTOR).doesNotExist();
      assert.dom(JOIN_BUTTON_SELECTOR).isNotDisabled("the user can try again");
    });

    test("does not resume a stale marker", async function (assert) {
      window.sessionStorage.setItem(
        resumeStorageKey(1),
        JSON.stringify({ topicId: 1, attempts: 1, at: Date.now() - 300_000 })
      );

      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      assert.false(performJoin.called);
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
