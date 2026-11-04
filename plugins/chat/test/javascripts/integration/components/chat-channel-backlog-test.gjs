import { getOwner } from "@ember/owner";
import {
  find,
  findAll,
  render,
  settled,
  triggerEvent,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { publishToMessageBus } from "discourse/tests/helpers/qunit-helpers";
import ChatChannel from "discourse/plugins/chat/discourse/components/chat-channel";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

// What the server holds. The reader is caught up on LAST_READ, everything above
// it is backlog, and LIVE is posted while they are still mid-stream. The stream
// is long on purpose: paging on mount cannot reach the end on its own.
const STREAM = Array.from({ length: 40 }, (_, i) => i + 1);
const LAST_READ = 20;
const LIVE = 40;

// Truncated per request regardless of what the loader asks for, so catching up
// on the backlog takes several pages the way a big one would.
const PAGE = 3;

const AUTHOR = {
  id: 2,
  username: "hawk",
  name: null,
  avatar_template: "/letter_avatar_proxy/v4/letter/t/f9ae1b/{size}.png",
};

const createdAt = (id) =>
  new Date(Date.UTC(2025, 0, 1, 8, 0, 0) + id * 60_000).toISOString();

function messageJson(id) {
  return {
    id,
    message: `message ${id}`,
    cooked: `<p>message ${id}</p>`,
    excerpt: `message ${id}`,
    created_at: createdAt(id),
    flag_count: 0,
    user: AUTHOR,
    available_flags: ["spam"],
  };
}

function meta({ past = null, future = null }) {
  return {
    can_load_more_past: past,
    can_load_more_future: future,
    can_delete_self: true,
    can_delete_others: true,
    can_flag: true,
    user_silenced: false,
    can_moderate: true,
  };
}

const below = (target) => STREAM.filter((id) => id > target);
const above = (target) => STREAM.filter((id) => id < target);

// Mirrors Chat::MessagesQuery: query_around_target for the opening request,
// query_paginated_messages afterwards. A page answers only for its own
// direction, and the other flag comes back nil.
function messagesHandler({ queryParams }) {
  const { direction } = queryParams;
  const target = Number(queryParams.target_message_id);

  if (!direction) {
    const past = above(LAST_READ).slice(-PAGE);
    const future = below(LAST_READ).slice(0, PAGE);
    return response({
      messages: [...past, LAST_READ, ...future].map(messageJson),
      meta: meta({ past: true, future: true }),
    });
  }

  if (direction === "future") {
    const page = below(target).slice(0, PAGE);
    return response({
      messages: page.map(messageJson),
      meta: meta({ future: below(page.at(-1) ?? target).length > 0 }),
    });
  }

  const prior = above(target);
  return response({
    messages: prior.slice(-PAGE).reverse().map(messageJson),
    meta: meta({ past: prior.length > PAGE }),
  });
}

// The scroller is column-reverse, so distanceToBottom is -scrollTop: 0 is the
// live edge and -(scrollHeight - clientHeight) is the top.
function setScrollerHeight(scroller, { clientHeight, scrollHeight }) {
  for (const [key, value] of Object.entries({ clientHeight, scrollHeight })) {
    Object.defineProperty(scroller, key, { configurable: true, value });
  }
}

async function scrollToEdge(edge) {
  const scroller = find(".chat-messages-scroller");
  setScrollerHeight(scroller, { clientHeight: 300, scrollHeight: 3000 });
  scroller.scrollTop = edge === "bottom" ? 0 : -2700;

  // the opening fetch sets _ignoreNextScroll, so the first event is swallowed
  for (let i = 0; i < 2; i++) {
    await triggerEvent(scroller, "scroll");
  }
}

// Touches the bottom only in passing, the way a quick scroll does, so the
// scroll ends just above it. Dispatched directly because triggerEvent fires
// after a tick, by which time the scroller has already moved on.
async function skimPastBottom() {
  const scroller = find(".chat-messages-scroller");
  setScrollerHeight(scroller, { clientHeight: 300, scrollHeight: 3000 });
  scroller.scrollTop = 0;
  scroller.dispatchEvent(new Event("scroll"));
  scroller.scrollTop = -100;
  await settled();
}

function renderedMessageIds() {
  return [
    ...new Set(
      findAll(".chat-message-container[data-id]").map((element) =>
        Number(element.dataset.id)
      )
    ),
  ].sort((a, b) => a - b);
}

module("Integration | Component | ChatChannel", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.fabricators = new ChatFabricators(getOwner(this));

    pretender.get("/chat/api/channels/1/messages", messagesHandler);
    pretender.get("/chat/api/me/channels", () =>
      response({ direct_message_channels: [], public_channels: [] })
    );
    pretender.put("/chat/api/channels/1/read", () =>
      response({ success: true })
    );
    pretender.post("/chat/api/channels/1/drafts", () =>
      response({ success: true })
    );

    // Opens the channel the way a back-reader does: at the last read message,
    // with unread history still below the loaded window.
    this.openBacklog = async (assert) => {
      this.channel = this.fabricators.channel({ id: 1 });
      this.channel.currentUserMembership.following = true;
      this.channel.currentUserMembership.lastReadMessageId = LAST_READ;

      await render(
        <template><ChatChannel @channel={{this.channel}} /></template>
      );

      const loaded = renderedMessageIds();
      assert.true(loaded.includes(LAST_READ), "the last read message is shown");
      assert.false(loaded.includes(LIVE), "the end of the stream is not shown");
      assert.true(
        LIVE - Math.max(...loaded) > 1,
        `history is still outstanding below the window (loaded up to ${Math.max(
          ...loaded
        )}, live is ${LIVE})`
      );
    };

    // Another user posts while the reader is still mid-page.
    this.receiveLiveMessage = async () => {
      publishToMessageBus("/chat/1", {
        type: "sent",
        chat_message: messageJson(LIVE),
      });
      await settled();
    };
  });

  test("a live message waits behind unloaded history, and paging reaches it without gaps", async function (assert) {
    await this.openBacklog(assert);
    const windowTop = Math.max(...renderedMessageIds());

    // a past page must leave the forward stream open
    await scrollToEdge("top");

    await this.receiveLiveMessage();
    assert.false(
      renderedMessageIds().includes(LIVE),
      "the live message waits until the history before it is loaded"
    );

    for (let i = 0, seen = 0; i < 40; i++) {
      await scrollToEdge("bottom");
      const requests = pretender.handledRequests.length;
      if (requests === seen) {
        break;
      }
      seen = requests;
    }

    const rendered = renderedMessageIds();
    const stranded = STREAM.filter(
      (id) => id > windowTop && !rendered.includes(id)
    );

    assert.true(rendered.includes(LIVE), "the live message is rendered");
    assert.deepEqual(
      stranded,
      [],
      `no message between the loaded window (${windowTop}) and the live one (${LIVE}) was skipped`
    );
  });

  test("held live messages stop keeping the arrow up once their page loads", async function (assert) {
    await this.openBacklog(assert);
    await scrollToEdge("top");
    await this.receiveLiveMessage();

    for (let i = 0; i < 40 && !renderedMessageIds().includes(LIVE); i++) {
      await skimPastBottom();
    }

    assert.true(renderedMessageIds().includes(LIVE), "the live message loaded");
    assert
      .dom(".chat-scroll-to-bottom__button.visible")
      .doesNotExist("the arrow hides near the end, as it does for history");
  });

  test("a message replayed while the channel loads is not counted as new", async function (assert) {
    let releaseLoad;
    pretender.get("/chat/api/channels/1/messages", async (request) => {
      if (!request.queryParams.direction) {
        await new Promise((resolve) => (releaseLoad = resolve));
      }
      return messagesHandler(request);
    });

    this.channel = this.fabricators.channel({ id: 1 });
    this.channel.currentUserMembership.following = true;
    this.channel.currentUserMembership.lastReadMessageId = LAST_READ;
    const rendering = render(
      <template><ChatChannel @channel={{this.channel}} /></template>
    );
    await waitUntil(() => releaseLoad);

    // subscribing replays posts made while the reader was elsewhere
    const replayed = publishToMessageBus("/chat/1", {
      type: "sent",
      chat_message: messageJson(LAST_READ + 1),
    });

    assert.strictEqual(
      this.owner.lookup("service:chat-pane-pending-manager")
        .totalPendingMessageCount,
      0,
      "it is not counted as a new message below"
    );

    releaseLoad();
    await Promise.all([rendering, replayed]);

    assert.true(
      renderedMessageIds().includes(LAST_READ + 1),
      "the message is shown from the loaded page"
    );
  });

  test("reaching the end while an older page loads still checks for newer messages", async function (assert) {
    // a window that ends on a full page is reported as having more ahead
    let releasePast;
    pretender.get("/chat/api/channels/1/messages", async ({ queryParams }) => {
      if (queryParams.direction === "past") {
        await new Promise((resolve) => (releasePast = resolve));
        return response({
          messages: [15, 16, 17].map(messageJson),
          meta: meta({ past: false }),
        });
      }

      if (queryParams.direction === "future") {
        return response({ messages: [], meta: meta({ future: false }) });
      }

      return response({
        messages: [18, 19, LAST_READ].map(messageJson),
        meta: meta({ past: true, future: true }),
      });
    });

    this.channel = this.fabricators.channel({ id: 1 });
    this.channel.currentUserMembership.following = true;
    this.channel.currentUserMembership.lastReadMessageId = LAST_READ;
    const rendering = render(
      <template><ChatChannel @channel={{this.channel}} /></template>
    );

    await waitUntil(() => renderedMessageIds().length === 3);

    const scroller = find(".chat-messages-scroller");
    setScrollerHeight(scroller, { clientHeight: 300, scrollHeight: 3000 });
    scroller.scrollTop = -2700;
    triggerEvent(scroller, "scroll");
    triggerEvent(scroller, "scroll");
    await waitUntil(() => releasePast);

    scroller.scrollTop = 0;
    triggerEvent(scroller, "scroll");
    triggerEvent(scroller, "scroll");
    await new Promise((resolve) => setTimeout(resolve, 100));

    releasePast();
    await rendering;
    await settled();

    assert.true(
      pretender.handledRequests.some(
        (request) => request.queryParams.direction === "future"
      ),
      "newer messages are requested once the older page is in"
    );
    assert
      .dom(".chat-scroll-to-bottom__button.visible")
      .doesNotExist("the arrow is hidden at the real end");
  });
});
