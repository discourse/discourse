import { getOwner } from "@ember/owner";
import { click, currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const ROOM = {
  id: 1,
  name: "Sala do Bar",
  slug: "sala-do-bar",
  public: true,
  room_type: "open",
  active_participants: [],
};

function stubRooms(needs) {
  needs.settings({ voice_enabled: true });
  needs.pretender((server, helper) => {
    server.get("/voice/rooms.json", () =>
      helper.response({ rooms: [ROOM], can_create_room: false })
    );
    server.get(`/voice/rooms/${ROOM.slug}.json`, () =>
      helper.response({ room: ROOM })
    );
  });
}

function stubJoin(context) {
  const joined = [];
  const voiceWebrtc = getOwner(context).lookup("service:voice-webrtc");
  voiceWebrtc.join = (room) => {
    joined.push(room.slug);
    return Promise.resolve();
  };
  return { joined, voiceWebrtc };
}

acceptance("Voice room widget mode", function (needs) {
  needs.user();
  stubRooms(needs);

  test("joins the room without leaving the current page", async function (assert) {
    await visit("/latest");
    const { joined } = stubJoin(this);

    try {
      await visit(`/voice/r/${ROOM.slug}?join=true&widget=true`);
    } catch (error) {
      assert.strictEqual(
        error.message,
        "TransitionAborted",
        "it aborts the transition"
      );
    }

    assert.strictEqual(currentURL(), "/latest", "stays where the user was");
    assert.deepEqual(joined, [ROOM.slug], "joins the room in the background");
  });

  test("lands on the homepage when opened from a full page load", async function (assert) {
    const { joined } = stubJoin(this);

    await visit(`/voice/r/${ROOM.slug}?join=true&widget=true`);

    assert.strictEqual(currentURL(), "/latest", "does not open the room page");
    assert.deepEqual(joined, [ROOM.slug], "joins the room in the background");
  });

  test("accepts a valueless widget param", async function (assert) {
    const { joined } = stubJoin(this);

    await visit(`/voice/r/${ROOM.slug}?join=true&widget`);

    assert.strictEqual(currentURL(), "/latest", "does not open the room page");
    assert.deepEqual(joined, [ROOM.slug], "joins the room in the background");
  });

  test("ignores an explicitly falsy widget param", async function (assert) {
    const { joined } = stubJoin(this);

    await visit(`/voice/r/${ROOM.slug}?widget=false`);

    assert.strictEqual(
      currentURL(),
      `/voice/r/${ROOM.slug}?widget=false`,
      "opens the room page"
    );
    assert.deepEqual(joined, [], "does not join");
  });

  test("needs a join to dock, so the widget param alone opens the room page", async function (assert) {
    const { joined } = stubJoin(this);

    await visit(`/voice/r/${ROOM.slug}?widget=true`);

    assert.strictEqual(
      currentURL(),
      `/voice/r/${ROOM.slug}?widget=true`,
      "opens the room page"
    );
    assert.deepEqual(joined, [], "does not join without being asked to");
  });

  test("docks the call back to the page the user came from when they join", async function (assert) {
    const { joined, voiceWebrtc } = stubJoin(this);
    voiceWebrtc.setCallWidgetHidden(true);

    await visit("/t/internationalization-localization/280");
    await visit(`/voice/r/${ROOM.slug}?widget=true`);
    await click(".voice-room-page__join");

    assert.deepEqual(joined, [ROOM.slug], "joins the room");
    assert.strictEqual(
      currentURL(),
      "/t/internationalization-localization/280",
      "returns to where the user was instead of resetting their place"
    );
    assert.false(
      voiceWebrtc.callWidgetHidden,
      "the call widget is no longer hidden"
    );
  });

  test("skips room pages when picking somewhere to return to", async function (assert) {
    const { joined } = stubJoin(this);
    // Consuming `?join` leaves this room in the history under another spelling.
    getOwner(this)
      .lookup("service:session-store")
      .setObject({
        key: "routeHistory",
        value: [`/voice/r/${ROOM.slug}?join=true`, "/latest"],
      });

    await visit(`/voice/r/${ROOM.slug}?widget=true`);
    await click(".voice-room-page__join");

    assert.deepEqual(joined, [ROOM.slug], "joins the room");
    assert.strictEqual(
      currentURL(),
      "/latest",
      "does not dock back onto a room page"
    );
  });

  test("docks to the homepage when there is nowhere to return to", async function (assert) {
    const { joined } = stubJoin(this);
    getOwner(this).lookup("service:session-store").remove("routeHistory");

    await visit(`/voice/r/${ROOM.slug}?widget=true`);
    await click(".voice-room-page__join");

    assert.deepEqual(joined, [ROOM.slug], "joins the room");
    assert.strictEqual(currentURL(), "/latest", "leaves the room page");
  });

  test("keeps a join on the room page when the param is falsy", async function (assert) {
    const { joined } = stubJoin(this);

    await visit(`/voice/r/${ROOM.slug}?widget=false`);
    await click(".voice-room-page__join");

    assert.deepEqual(joined, [ROOM.slug], "joins the room");
    assert.strictEqual(
      currentURL(),
      `/voice/r/${ROOM.slug}?widget=false`,
      "stays on the room page"
    );
  });

  test("leaves a join without a widget param on the room page", async function (assert) {
    const { joined } = stubJoin(this);

    await visit(`/voice/r/${ROOM.slug}?join=true`);

    assert.strictEqual(
      currentURL(),
      `/voice/r/${ROOM.slug}`,
      "opens the room page and consumes the join param"
    );
    assert.deepEqual(joined, [ROOM.slug], "the room page joins the call");
  });

  test("shows a widget the user had dismissed", async function (assert) {
    const { voiceWebrtc } = stubJoin(this);
    voiceWebrtc.setCallWidgetHidden(true);

    await visit(`/voice/r/${ROOM.slug}?join=true&widget=true`);

    assert.false(
      voiceWebrtc.callWidgetHidden,
      "the call widget is no longer hidden"
    );
  });

  test("opens the room page when the params are absent", async function (assert) {
    const { joined } = stubJoin(this);

    await visit(`/voice/r/${ROOM.slug}`);

    assert.strictEqual(currentURL(), `/voice/r/${ROOM.slug}`);
    assert.deepEqual(joined, [], "does not join without being asked to");
  });
});

acceptance("Voice room widget mode - anonymous", function (needs) {
  stubRooms(needs);
  needs.site({ voice_public_access: true });

  test("does not dock the call, since anonymous visitors cannot join", async function (assert) {
    const { joined } = stubJoin(this);

    await visit(`/voice/r/${ROOM.slug}?join=true&widget=true`);

    // The room page takes the join request instead, which prompts for a login.
    assert.strictEqual(currentURL(), "/login", "prompts for a login");
    assert.deepEqual(joined, [], "does not join");
  });

  test("opens the room page for a widget param on its own", async function (assert) {
    await visit(`/voice/r/${ROOM.slug}?widget=true`);

    assert.strictEqual(
      currentURL(),
      `/voice/r/${ROOM.slug}?widget=true`,
      "opens the room page"
    );
  });
});
