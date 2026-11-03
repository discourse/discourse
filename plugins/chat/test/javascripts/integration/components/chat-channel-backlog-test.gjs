import { getOwner } from "@ember/owner";
import {
  find,
  findAll,
  render,
  settled,
  triggerEvent,
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

function renderedMessageIds() {
  return [
    ...new Set(
      findAll(".chat-message-container[data-id]").map((element) =>
        Number(element.dataset.id)
      )
    ),
  ].sort((a, b) => a - b);
}

function futurePageCursors() {
  return pretender.handledRequests
    .filter(
      ({ method, url }) =>
        method === "GET" && url.includes("/chat/api/channels/1/messages")
    )
    .map((request) => new URL(request.url, "http://discourse.test"))
    .filter((url) => url.searchParams.get("direction") === "future")
    .map((url) => Number(url.searchParams.get("target_message_id")));
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

  test("a live push does not become the forward cursor", async function (assert) {
    await this.openBacklog(assert);

    // used to null can_load_more_future and close the stream early
    await scrollToEdge("top");

    // mount-time paging already issued forward requests, so only the ones after
    // the push say anything about the bug
    const cursorsBeforePush = futurePageCursors().length;

    await this.receiveLiveMessage();
    assert.true(
      renderedMessageIds().includes(LIVE),
      "the live message renders at the end of the partially loaded list"
    );

    await scrollToEdge("bottom");

    const cursors = futurePageCursors().slice(cursorsBeforePush);
    assert.true(
      cursors.length > 0,
      "scrolling to the bottom still requests a forward page"
    );
    assert.true(
      cursors[0] < LIVE,
      `the forward page resumes from loaded history (${cursors[0]}), not from the live message (${LIVE})`
    );
  });

  test("paging to the end of the stream leaves nothing stranded", async function (assert) {
    await this.openBacklog(assert);

    const windowTop = Math.max(...renderedMessageIds());
    const gap = STREAM.filter((id) => id > windowTop && id < LIVE);
    assert.true(
      gap.length > 0,
      `the backlog to bridge is ${gap.length} messages`
    );

    await this.receiveLiveMessage();

    // the precondition the bug needs: the live message is on screen while
    // history between it and the loaded window is still missing
    const hole = gap.filter((id) => !renderedMessageIds().includes(id));
    assert.true(
      hole.length > 0,
      `a hole of ${hole.length} messages sits under the live message`
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
    const stranded = gap.filter((id) => !rendered.includes(id));

    assert.true(rendered.includes(LIVE), "the live message is rendered");
    assert.deepEqual(
      stranded,
      [],
      `no message between the loaded window (${windowTop}) and the live one (${LIVE}) was skipped`
    );
  });
});
