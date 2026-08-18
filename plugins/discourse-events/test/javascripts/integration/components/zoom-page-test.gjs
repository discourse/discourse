import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import LivestreamZoomPage from "../../discourse/components/livestream/zoom-page";

const FALLBACK_SELECTOR = ".discourse-calendar-livestream-zoom-page__fallback";
const FRAME_SELECTOR = ".discourse-calendar-livestream-zoom-page__frame";
const CHAT_SELECTOR = ".discourse-calendar-livestream-zoom-page__chat";

// The frame's URL is served by Discourse, and left to itself the frame would
// load it here — where anything unrecognised answers with the app, leaving a
// second copy of it running inside the test. `zoom-frame-url-test` covers what
// the URL should be.
function stubFrameUrl(context) {
  sinon.stub(LivestreamZoomPage.prototype, "frameUrl").get(() => "about:blank");
  return context;
}

// What the frame reports back — the meeting failing, and the user leaving it —
// arrives as a window message, which is the same channel the test runner uses
// to talk to its own harness. Faking one here unsettles it, so those states are
// left to a system test driving the real frame.

// The channel itself is chat's to render and needs a live channel record, so
// only the decision to embed it is exercised here. Registering is repeatable,
// which a test flipping `userCanChat` for itself depends on.
function stubChat(context, userCanChat = true) {
  const owner = getOwner(context);

  owner.unregister("service:embeddable-chat");
  owner.register(
    "service:embeddable-chat",
    { userCanChat },
    { instantiate: false }
  );

  // Never resolving, rather than resolving to nothing: the channel it is asked
  // for is assigned to tracked state that the same modifier reads, so anything
  // it hands back that is not the channel being looked for invalidates the
  // modifier and sets it looking again. A real one matches and settles; a blank
  // one spins.
  owner.unregister("service:chat-channels-manager");
  owner.register(
    "service:chat-channels-manager",
    { find: () => new Promise(() => {}) },
    { instantiate: false }
  );
}

// The embedded channel subscribes for its own membership updates, and a live
// subscription is a request that never finishes, which is a test that never
// settles. Only the subscribing is taken out: the service itself is left in
// place for everything else that expects to find it.
//
// Once per test, unlike the services above: a second wrapping of the same
// method is an error in sinon, not a no-op.
function stubMessageBus(context) {
  const messageBus = getOwner(context).lookup("service:message-bus");

  sinon.stub(messageBus, "subscribe");
  sinon.stub(messageBus, "unsubscribe");
}

function stubEventApi(context) {
  const api = {
    joinEvent: sinon.fake.resolves(),
    updateEventAttendance: sinon.fake.resolves(),
  };

  const owner = getOwner(context);
  owner.unregister("service:discourse-post-event-api");
  owner.register("service:discourse-post-event-api", api, {
    instantiate: false,
  });

  return api;
}

module("Integration | Component | LivestreamZoomPage", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    getOwner(this).lookup("service:site-settings").chat_enabled = true;
    stubChat(this);
    stubMessageBus(this);
    stubFrameUrl(this);
    this.eventApi = stubEventApi(this);

    this.topic = {
      id: 1,
      slug: "test-topic",
      chat_channel_id: 9,
      postStream: {
        posts: [
          {
            event: {
              id: 2,
              creator: { id: 1, username: "test-user" },
              livestream_url: "https://us06web.zoom.us/j/123456789",
              starts_at: moment().subtract(5, "minutes").toISOString(),
              ends_at: moment().add(1, "hour").toISOString(),
            },
          },
        ],
      },
    };
  });

  test("hands the meeting a frame of its own to run in", async function (assert) {
    await render(
      <template><LivestreamZoomPage @topic={{this.topic}} /></template>
    );

    assert
      .dom(FRAME_SELECTOR)
      .hasAttribute(
        "allow",
        /microphone/,
        "the meeting cannot ask for audio without it"
      );
    assert.dom(FALLBACK_SELECTOR).doesNotExist("no error before a failure");
  });

  // The states before and after the event's own timeframe render the event
  // card, which does not settle in a rendering test. What it is gating is the
  // signature the meeting cannot start without, and `livestream_controller_spec`
  // covers the server refusing that outside the timeframe.

  test("embeds the chat below the meeting when the topic has a channel", async function (assert) {
    await render(
      <template><LivestreamZoomPage @topic={{this.topic}} /></template>
    );

    assert.dom(CHAT_SELECTOR).exists();
    assert.dom(`${CHAT_SELECTOR} #custom-chat-container`).hasClass("inline");
  });

  test("omits the chat when chat is disabled", async function (assert) {
    getOwner(this).lookup("service:site-settings").chat_enabled = false;

    await render(
      <template><LivestreamZoomPage @topic={{this.topic}} /></template>
    );

    assert.dom(CHAT_SELECTOR).doesNotExist();
  });

  test("omits the chat when the topic has no channel", async function (assert) {
    this.topic.chat_channel_id = null;

    await render(
      <template><LivestreamZoomPage @topic={{this.topic}} /></template>
    );

    assert.dom(CHAT_SELECTOR).doesNotExist();
  });

  test("omits the chat when the user cannot chat", async function (assert) {
    stubChat(this, false);

    await render(
      <template><LivestreamZoomPage @topic={{this.topic}} /></template>
    );

    assert.dom(CHAT_SELECTOR).doesNotExist();
  });
  // Chat beside the meeting is read-only for anyone the event has no "going"
  // answer from, so reaching the meeting is taken as that answer.
  test("marks a user who has not answered the RSVP as going", async function (assert) {
    this.topic.postStream.posts[0].event.can_update_attendance = true;

    await render(
      <template><LivestreamZoomPage @topic={{this.topic}} /></template>
    );

    assert.true(
      this.eventApi.joinEvent.calledWithMatch(sinon.match.any, {
        status: "going",
      }),
      "the user is entered into the event on the way in"
    );
  });

  test("leaves an answer the user has already given alone", async function (assert) {
    const event = this.topic.postStream.posts[0].event;
    event.can_update_attendance = true;
    event.watching_invitee = { id: 5, status: "not_going" };

    await render(
      <template><LivestreamZoomPage @topic={{this.topic}} /></template>
    );

    assert.false(this.eventApi.joinEvent.called, "no answer is overwritten");
    assert.false(this.eventApi.updateEventAttendance.called);
  });

  test("does not answer for a user the event will not take one from", async function (assert) {
    await render(
      <template><LivestreamZoomPage @topic={{this.topic}} /></template>
    );

    assert.false(this.eventApi.joinEvent.called);
  });
});
