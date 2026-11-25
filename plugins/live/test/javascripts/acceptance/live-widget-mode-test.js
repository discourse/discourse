import { getOwner } from "@ember/owner";
import {
  click,
  currentURL,
  fillIn,
  visit,
  waitUntil,
} from "@ember/test-helpers";
import { test } from "qunit";
import MentionsListEmptyState from "discourse/components/user-menu/mentions-list-empty-state";
import { withPluginApi } from "discourse/lib/plugin-api";
import {
  acceptance,
  loggedInUser,
} from "discourse/tests/helpers/qunit-helpers";

const ROOM = {
  id: 1,
  name: "Sala do Bar",
  slug: "sala-do-bar",
  public: true,
  room_type: "open",
  active_participants: [],
};

function stubRooms(needs, settings = {}) {
  needs.settings({ live_enabled: true, ...settings });
  needs.pretender((server, helper) => {
    server.get("/live/rooms.json", () =>
      helper.response({ rooms: [ROOM], can_create_room: false })
    );
    server.get(`/live/rooms/${ROOM.slug}.json`, () =>
      helper.response({ room: ROOM })
    );
  });
}

function stubJoin(context) {
  const joined = [];
  const liveWebrtc = getOwner(context).lookup("service:live-webrtc");
  liveWebrtc.join = (room) => {
    joined.push(room.slug);
    return Promise.resolve();
  };
  return { joined, liveWebrtc };
}

acceptance("Live room widget mode", function (needs) {
  needs.user();
  stubRooms(needs);

  test("joins the room without leaving the current page", async function (assert) {
    await visit("/latest");
    const { joined } = stubJoin(this);

    try {
      await visit(`/live/r/${ROOM.slug}?join=true&widget=true`);
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

    await visit(`/live/r/${ROOM.slug}?join=true&widget=true`);

    assert.strictEqual(currentURL(), "/latest", "does not open the room page");
    assert.deepEqual(joined, [ROOM.slug], "joins the room in the background");
  });

  test("accepts a valueless widget param", async function (assert) {
    const { joined } = stubJoin(this);

    await visit(`/live/r/${ROOM.slug}?join=true&widget`);

    assert.strictEqual(currentURL(), "/latest", "does not open the room page");
    assert.deepEqual(joined, [ROOM.slug], "joins the room in the background");
  });

  test("ignores an explicitly falsy widget param", async function (assert) {
    const { joined } = stubJoin(this);

    await visit(`/live/r/${ROOM.slug}?widget=false`);

    assert.strictEqual(
      currentURL(),
      `/live/r/${ROOM.slug}?widget=false`,
      "opens the room page"
    );
    assert.deepEqual(joined, [], "does not join");
  });

  test("needs a join to dock, so the widget param alone opens the room page", async function (assert) {
    const { joined } = stubJoin(this);

    await visit(`/live/r/${ROOM.slug}?widget=true`);

    assert.strictEqual(
      currentURL(),
      `/live/r/${ROOM.slug}?widget=true`,
      "opens the room page"
    );
    assert.deepEqual(joined, [], "does not join without being asked to");
  });

  test("docks the call back to the page the user came from when they join", async function (assert) {
    const { joined, liveWebrtc } = stubJoin(this);
    liveWebrtc.setCallWidgetHidden(true);

    await visit("/t/internationalization-localization/280");
    await visit(`/live/r/${ROOM.slug}?widget=true`);
    await click(".live-room-page__join");

    assert.deepEqual(joined, [ROOM.slug], "joins the room");
    assert.strictEqual(
      currentURL(),
      "/t/internationalization-localization/280",
      "returns to where the user was instead of resetting their place"
    );
    assert.false(
      liveWebrtc.callWidgetHidden,
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
        value: [`/live/r/${ROOM.slug}?join=true`, "/latest"],
      });

    await visit(`/live/r/${ROOM.slug}?widget=true`);
    await click(".live-room-page__join");

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

    await visit(`/live/r/${ROOM.slug}?widget=true`);
    await click(".live-room-page__join");

    assert.deepEqual(joined, [ROOM.slug], "joins the room");
    assert.strictEqual(currentURL(), "/latest", "leaves the room page");
  });

  test("keeps a join on the room page when the param is falsy", async function (assert) {
    const { joined } = stubJoin(this);

    await visit(`/live/r/${ROOM.slug}?widget=false`);
    await click(".live-room-page__join");

    assert.deepEqual(joined, [ROOM.slug], "joins the room");
    assert.strictEqual(
      currentURL(),
      `/live/r/${ROOM.slug}?widget=false`,
      "stays on the room page"
    );
  });

  test("leaves a join without a widget param on the room page", async function (assert) {
    const { joined } = stubJoin(this);

    await visit(`/live/r/${ROOM.slug}?join=true`);

    assert.strictEqual(
      currentURL(),
      `/live/r/${ROOM.slug}`,
      "opens the room page and consumes the join param"
    );
    assert.deepEqual(joined, [ROOM.slug], "the room page joins the call");
  });

  test("shows a widget the user had dismissed", async function (assert) {
    const { liveWebrtc } = stubJoin(this);
    liveWebrtc.setCallWidgetHidden(true);

    await visit(`/live/r/${ROOM.slug}?join=true&widget=true`);

    assert.false(
      liveWebrtc.callWidgetHidden,
      "the call widget is no longer hidden"
    );
  });

  test("opens the room page when the params are absent", async function (assert) {
    const { joined } = stubJoin(this);

    await visit(`/live/r/${ROOM.slug}`);

    assert.strictEqual(currentURL(), `/live/r/${ROOM.slug}`);
    assert.deepEqual(joined, [], "does not join without being asked to");
  });
});

acceptance("Live room widget mode - anonymous", function (needs) {
  stubRooms(needs);
  needs.site({ live_public_access: true });

  test("does not dock the call, since anonymous visitors cannot join", async function (assert) {
    const { joined } = stubJoin(this);

    await visit(`/live/r/${ROOM.slug}?join=true&widget=true`);

    // The room page takes the join request instead, which prompts for a login.
    assert.strictEqual(currentURL(), "/login", "prompts for a login");
    assert.deepEqual(joined, [], "does not join");
  });

  test("opens the room page for a widget param on its own", async function (assert) {
    await visit(`/live/r/${ROOM.slug}?widget=true`);

    assert.strictEqual(
      currentURL(),
      `/live/r/${ROOM.slug}?widget=true`,
      "opens the room page"
    );
  });
});

function setupContextRoomStorage(needs, roomId) {
  needs.hooks.beforeEach(function () {
    this.contextRoomStore = this.owner.lookup("service:session-store");
    const userId = loggedInUser().id;
    this.contextRoomKey = `live-context-room:${userId}`;
    this.contextViewKey = `page-shell-context-view:${userId}`;
    if (roomId) {
      this.contextRoomStore.setItem(this.contextRoomKey, roomId);
    }
  });

  needs.hooks.afterEach(function () {
    this.contextRoomStore.remove(this.contextRoomKey);
    this.contextRoomStore.remove(`${this.contextRoomKey}:view`);
    this.contextRoomStore.remove(this.contextViewKey);
  });
}

acceptance("Live room in page shell Context", function (needs) {
  needs.user();
  stubRooms(needs, {
    enable_page_shell_prototype: true,
    enable_main_outlet_grid_layout_change: true,
    navigation_menu: "sidebar",
  });
  setupContextRoomStorage(needs);

  test("clicking a sidebar room joins in Context and keeps the room through forum navigation", async function (assert) {
    const pageShell = getOwner(this).lookup("service:page-shell");
    const { joined } = stubJoin(this);
    const roomInContext = "#page-shell-context .live-room-page";

    await visit("/latest");
    await waitUntil(() => pageShell.canOpenContext);
    assert
      .dom(".page-shell__header-context select")
      .hasValue("about", "shows About before a room is selected");

    await click("#toggle-context-panel");
    await click(".sidebar-section-link[data-link-name='live-room-1']");

    assert.strictEqual(currentURL(), "/latest", "keeps the current page");
    assert.deepEqual(joined, [ROOM.slug], "joins the room once");
    assert.dom(roomInContext).isVisible("opens Context with the room visible");
    assert
      .dom(".page-shell__header-context select option:checked")
      .hasText("Live", "shows Live as the selected Context view");
    const owner = getOwner(this);
    assert.strictEqual(
      this.contextRoomStore.getInt(this.contextRoomKey),
      ROOM.id,
      "remembers the selected room for this tab"
    );
    assert.strictEqual(
      owner.lookup("service:key-value-store").getObject("page-shell-panels")
        .context.mode,
      "open",
      "remembers that Context was opened"
    );

    await visit("/t/internationalization-localization/280");
    assert.dom(roomInContext).isVisible("keeps the room visible on a topic");

    await click(".live-context-room__expand");
    assert.strictEqual(
      currentURL(),
      `/live/r/${ROOM.slug}`,
      "opens the full room"
    );
    assert
      .dom("#main-outlet-wrapper[data-full-page] .live-room-page")
      .exists("renders Live in a full page outside the shell");
    assert.dom(".page-shell").doesNotExist("leaves the split layout");
    assert.dom(".sidebar-wrapper").doesNotExist("hides the sidebar");
    assert.dom(roomInContext).doesNotExist("renders one room surface");

    await click(".live-room-header__panel-view");
    assert.strictEqual(
      currentURL(),
      "/t/internationalization-localization/280",
      "returns to the topic"
    );
    assert.dom(roomInContext).isVisible("restores the room in Context");
    assert.deepEqual(joined, [ROOM.slug], "switching views does not rejoin");
  });

  test("the Context picker switches between About and Live without rejoining", async function (assert) {
    const pageShell = getOwner(this).lookup("service:page-shell");
    const { joined, liveWebrtc } = stubJoin(this);
    const picker = ".page-shell__header-context select";
    const room = "#page-shell-context .live-room-page";

    withPluginApi((api) => {
      api.registerValueTransformer("page-shell-context-view", ({ value }) => [
        ...value,
        {
          id: "mentions",
          label: "user.no_mentions_title",
          component: MentionsListEmptyState,
        },
      ]);
    });

    await visit("/latest");
    await waitUntil(() => pageShell.canOpenContext);
    await click(".sidebar-section-link[data-link-name='live-room-1']");
    liveWebrtc.activeRoomId = ROOM.id;

    assert
      .dom(`${picker} option[value="about"]`)
      .hasText("About", "keeps About in the picker");
    await fillIn(picker, "about");

    assert.dom(picker).hasValue("about", "selects About");
    assert
      .dom(room)
      .doesNotExist("shows the default panel instead of the room");
    assert.dom(".live-call-widget").doesNotExist("keeps the widget hidden");
    assert.strictEqual(
      liveWebrtc.activeRoomId,
      ROOM.id,
      "keeps the call active"
    );
    assert
      .dom(`${picker} option[value="live"]`)
      .hasText("Live", "keeps Live in the picker");

    await fillIn(picker, "mentions");

    assert.dom(picker).hasValue("mentions", "selects the additional view");
    assert
      .dom("#page-shell-context .empty-state")
      .isVisible("renders the component registered with the additional option");

    await fillIn(picker, "live");

    assert.dom(picker).hasValue("live", "selects Live");
    assert.dom(room).isVisible("restores the room");
    assert.deepEqual(joined, [ROOM.slug], "switching views does not rejoin");
  });

  test("closing Context keeps the call out of the floating widget", async function (assert) {
    const pageShell = getOwner(this).lookup("service:page-shell");
    const { joined, liveWebrtc } = stubJoin(this);

    await visit("/latest");
    await waitUntil(() => pageShell.canOpenContext);
    await click(".sidebar-section-link[data-link-name='live-room-1']");
    liveWebrtc.activeRoomId = ROOM.id;

    await click("#toggle-context-panel");

    assert.dom("#page-shell-context").doesNotExist("closes Context");
    assert.dom(".live-call-widget").doesNotExist("keeps the widget hidden");
    assert.strictEqual(
      liveWebrtc.activeRoomId,
      ROOM.id,
      "keeps the call active"
    );

    await click("#toggle-context-panel");

    assert
      .dom("#page-shell-context .live-room-page")
      .isVisible("reopens the room");
    assert.deepEqual(joined, [ROOM.slug], "reopening does not rejoin");
  });
});

acceptance("Live room in page shell Context after reload", function (needs) {
  needs.user();
  stubRooms(needs, {
    enable_page_shell_prototype: true,
    enable_main_outlet_grid_layout_change: true,
  });

  setupContextRoomStorage(needs, ROOM.id);

  test("restores the panel room without joining a call", async function (assert) {
    const { joined } = stubJoin(this);

    await visit("/latest");
    await waitUntil(
      () => getOwner(this).lookup("service:page-shell").canOpenContext
    );

    assert
      .dom("#page-shell-context .live-room-header__info-trigger")
      .hasText(ROOM.name, "shows the room remembered before the reload");
    assert
      .dom(".page-shell__header-context select")
      .hasValue("live", "shows Live for the restored room");
    assert.deepEqual(joined, [], "leaves rejoining to the user");
  });
});
