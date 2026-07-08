import { getOwner } from "@ember/owner";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import KeyValueStore from "discourse/lib/key-value-store";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { publishToMessageBus } from "discourse/tests/helpers/qunit-helpers";
import ChatPinnedMessageBar from "discourse/plugins/chat/discourse/components/chat/pinned-message-bar";
import { STORE_NAMESPACE } from "discourse/plugins/chat/discourse/lib/chat-pinned-bar-dismissal";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

function pinResponse(channel, count) {
  const pinned_messages = [];
  for (let i = 0; i < count; i++) {
    pinned_messages.push({
      id: 100 + i,
      chat_message_id: 200 + i,
      pinned_at: moment().subtract(i, "minute").toISOString(),
      pinned_by: { id: 1, username: "alice" },
      message: { id: 200 + i, excerpt: `Pinned excerpt ${i}`, message: "x" },
    });
  }
  return response({ pinned_messages, membership: null });
}

// pins given newest-first by id (matching the server's created_at DESC, id DESC)
function pinsResponse(ids) {
  return response({
    pinned_messages: ids.map((id, i) => ({
      id,
      chat_message_id: 200 + id,
      pinned_at: moment().subtract(i, "minute").toISOString(),
      pinned_by: { id: 1, username: "alice" },
      message: { id: 200 + id, excerpt: `Pin ${id}` },
    })),
    membership: null,
  });
}

// a single pin whose pin-record id is `pinId` (the value the bar compares
// against the dismissed-above id)
function dismissablePinResponse(pinId) {
  return response({
    pinned_messages: [
      {
        id: pinId,
        chat_message_id: 200,
        pinned_at: moment().toISOString(),
        pinned_by: { id: 1, username: "alice" },
        message: { id: 200, excerpt: "Pinned excerpt", message: "x" },
      },
    ],
    membership: null,
  });
}

module("Component | ChatPinnedMessageBar", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.chat_pinned_messages = true;
    this.channel = new ChatFabricators(getOwner(this)).channel();
    this.noop = () => {};
  });

  test("does not render when the channel has no pins", async function (assert) {
    this.channel.pinnedMessagesCount = 0;

    await render(
      <template>
        <ChatPinnedMessageBar
          @channel={{this.channel}}
          @onJumpToMessage={{this.noop}}
        />
      </template>
    );

    assert.dom(".chat-pinned-bar").doesNotExist();
  });

  test("does not render when the site setting is disabled", async function (assert) {
    this.siteSettings.chat_pinned_messages = false;
    this.channel.pinnedMessagesCount = 2;
    pretender.get(`/chat/api/channels/${this.channel.id}/pins`, () =>
      pinResponse(this.channel, 2)
    );

    await render(
      <template>
        <ChatPinnedMessageBar
          @channel={{this.channel}}
          @onJumpToMessage={{this.noop}}
        />
      </template>
    );

    assert.dom(".chat-pinned-bar").doesNotExist();
  });

  test("renders the most recent pin with no indicator for a single pin", async function (assert) {
    this.channel.pinnedMessagesCount = 1;
    pretender.get(`/chat/api/channels/${this.channel.id}/pins`, () =>
      pinResponse(this.channel, 1)
    );

    await render(
      <template>
        <ChatPinnedMessageBar
          @channel={{this.channel}}
          @onJumpToMessage={{this.noop}}
        />
      </template>
    );

    assert.dom(".chat-pinned-bar").exists();
    assert.dom(".chat-pinned-bar__excerpt").hasText("Pinned excerpt 0");
    assert.dom(".chat-pinned-bar__indicator").doesNotExist();
  });

  test("shows a position indicator for multiple pins", async function (assert) {
    this.channel.pinnedMessagesCount = 3;
    pretender.get(`/chat/api/channels/${this.channel.id}/pins`, () =>
      pinResponse(this.channel, 3)
    );

    await render(
      <template>
        <ChatPinnedMessageBar
          @channel={{this.channel}}
          @onJumpToMessage={{this.noop}}
        />
      </template>
    );

    assert.dom(".chat-pinned-bar__indicator-segment").exists({ count: 3 });
    assert
      .dom(".chat-pinned-bar__indicator-thumb")
      .exists({ count: 1 }, "a single bright bar marks the active pin");
    // oldest-at-top layout: the newest pin (shown first) sits in the bottom
    // slot, so its slot index is the last one (2 of 3)
    assert
      .dom(".chat-pinned-bar__indicator")
      .hasAttribute(
        "style",
        /--chat-pinned-bar-active:\s*2/,
        "starts on the newest pin, in the bottom slot"
      );

    await click(".chat-pinned-bar__main");

    assert
      .dom(".chat-pinned-bar__indicator")
      .hasAttribute(
        "style",
        /--chat-pinned-bar-active:\s*1/,
        "advancing to an older pin moves the highlight up a slot"
      );
  });

  test("scrolls the indicator window when there are more pins than fit", async function (assert) {
    this.channel.pinnedMessagesCount = 8;
    pretender.get(`/chat/api/channels/${this.channel.id}/pins`, () =>
      pinResponse(this.channel, 8)
    );

    await render(
      <template>
        <ChatPinnedMessageBar
          @channel={{this.channel}}
          @onJumpToMessage={{this.noop}}
        />
      </template>
    );

    // every pin has a segment; the window is capped/scrolled via the track.
    // newest is shown first and sits at the bottom, so the window starts
    // scrolled to the end: slot 7 centred => top = min(7 - 2, 8 - 4) = 4
    assert.dom(".chat-pinned-bar__indicator-segment").exists({ count: 8 });
    assert
      .dom(".chat-pinned-bar__indicator")
      .hasAttribute(
        "style",
        /indicator-top:\s*4/,
        "window starts at the bottom"
      );

    // advance toward older pins — the window scrolls up
    for (let i = 0; i < 6; i++) {
      await click(".chat-pinned-bar__main");
    }

    // active pin index 6 => slot 8 - 1 - 6 = 1 => top clamps to 0
    assert
      .dom(".chat-pinned-bar__indicator")
      .hasAttribute(
        "style",
        /indicator-top:\s*0/,
        "rail scrolled toward the oldest pin"
      );
  });

  test("clicking jumps to the current pin and cycles to the next", async function (assert) {
    this.channel.pinnedMessagesCount = 2;
    pretender.get(`/chat/api/channels/${this.channel.id}/pins`, () =>
      pinResponse(this.channel, 2)
    );

    let jumpedTo = null;
    this.onJump = (messageId) => (jumpedTo = messageId);

    await render(
      <template>
        <ChatPinnedMessageBar
          @channel={{this.channel}}
          @onJumpToMessage={{this.onJump}}
        />
      </template>
    );

    assert.dom(".chat-pinned-bar__excerpt").hasText("Pinned excerpt 0");

    await click(".chat-pinned-bar__main");

    assert.strictEqual(jumpedTo, 200, "jumps to the most recent pin");
    assert
      .dom(".chat-pinned-bar__excerpt")
      .hasText("Pinned excerpt 1", "advances to the next pin");

    await click(".chat-pinned-bar__main");

    assert.strictEqual(jumpedTo, 201, "jumps to the second pin");
    assert
      .dom(".chat-pinned-bar__excerpt")
      .hasText("Pinned excerpt 0", "wraps back to the first pin");
  });

  test("links to the full pinned messages list via the see-all icon", async function (assert) {
    this.channel.pinnedMessagesCount = 2;
    pretender.get(`/chat/api/channels/${this.channel.id}/pins`, () =>
      pinResponse(this.channel, 2)
    );

    await render(
      <template>
        <ChatPinnedMessageBar
          @channel={{this.channel}}
          @onJumpToMessage={{this.noop}}
        />
      </template>
    );

    assert.dom(".chat-pinned-bar__see-all").exists();
    assert
      .dom(".chat-pinned-bar__see-all")
      .hasAttribute("href", new RegExp(`/${this.channel.id}/pins$`));
  });

  test("shows an inline dismiss instead of the see-all icon for a single pin", async function (assert) {
    this.channel.pinnedMessagesCount = 1;
    pretender.get(`/chat/api/channels/${this.channel.id}/pins`, () =>
      pinResponse(this.channel, 1)
    );

    await render(
      <template>
        <ChatPinnedMessageBar
          @channel={{this.channel}}
          @onJumpToMessage={{this.noop}}
        />
      </template>
    );

    assert.dom(".chat-pinned-bar__see-all").doesNotExist();
    assert.dom(".chat-pinned-bar__dismiss").exists();

    await click(".chat-pinned-bar__dismiss");

    assert.dom(".chat-pinned-bar").hasClass("--dismissed");
  });

  test("keeps the see-all icon for pin managers with a single pin", async function (assert) {
    this.channel.meta.can_manage_pins = true;
    this.channel.pinnedMessagesCount = 1;
    pretender.get(`/chat/api/channels/${this.channel.id}/pins`, () =>
      pinResponse(this.channel, 1)
    );

    await render(
      <template>
        <ChatPinnedMessageBar
          @channel={{this.channel}}
          @onJumpToMessage={{this.noop}}
        />
      </template>
    );

    assert.dom(".chat-pinned-bar__dismiss").doesNotExist();
    assert.dom(".chat-pinned-bar__see-all").exists();
  });

  test("shows an unread indicator when there are unseen pins", async function (assert) {
    this.channel.pinnedMessagesCount = 2;
    pretender.get(`/chat/api/channels/${this.channel.id}/pins`, () =>
      pinResponse(this.channel, 2)
    );

    await render(
      <template>
        <ChatPinnedMessageBar
          @channel={{this.channel}}
          @onJumpToMessage={{this.noop}}
        />
      </template>
    );

    assert.dom(".chat-pinned-bar__unread-indicator").doesNotExist();

    this.channel.currentUserMembership = { has_unseen_pins: true };
    await settled();

    assert.dom(".chat-pinned-bar__unread-indicator").exists();
  });

  test("renders the server excerpt as decoded HTML, not double-escaped", async function (assert) {
    this.channel.pinnedMessagesCount = 1;
    pretender.get(`/chat/api/channels/${this.channel.id}/pins`, () =>
      response({
        pinned_messages: [
          {
            id: 100,
            chat_message_id: 200,
            pinned_at: moment().toISOString(),
            pinned_by: { id: 1, username: "alice" },
            // server excerpts arrive as entity-encoded HTML
            message: { id: 200, excerpt: "Rules &amp; etiquette&hellip;" },
          },
        ],
        membership: null,
      })
    );

    await render(
      <template>
        <ChatPinnedMessageBar
          @channel={{this.channel}}
          @onJumpToMessage={{this.noop}}
        />
      </template>
    );

    assert
      .dom(".chat-pinned-bar__excerpt")
      .hasText(
        "Rules & etiquette…",
        "decodes entities rather than escaping them"
      );
  });

  test("reloads pins on a pin/unpin message bus event", async function (assert) {
    let count = 1;
    this.channel.pinnedMessagesCount = 1;
    pretender.get(`/chat/api/channels/${this.channel.id}/pins`, () =>
      pinResponse(this.channel, count)
    );

    await render(
      <template>
        <ChatPinnedMessageBar
          @channel={{this.channel}}
          @onJumpToMessage={{this.noop}}
        />
      </template>
    );

    assert
      .dom(".chat-pinned-bar__indicator")
      .doesNotExist("starts with a single pin and no indicator");

    // another message gets pinned elsewhere
    count = 2;
    await publishToMessageBus(`/chat/${this.channel.id}`, {
      type: "pin",
      chat_message_id: 201,
    });
    await settled();

    assert
      .dom(".chat-pinned-bar__indicator-segment")
      .exists({ count: 2 }, "refetches and reflects both pins");
  });

  test("updates the preview when a pinned message is edited", async function (assert) {
    this.channel.pinnedMessagesCount = 1;
    pretender.get(`/chat/api/channels/${this.channel.id}/pins`, () =>
      pinResponse(this.channel, 1)
    );

    await render(
      <template>
        <ChatPinnedMessageBar
          @channel={{this.channel}}
          @onJumpToMessage={{this.noop}}
        />
      </template>
    );

    assert.dom(".chat-pinned-bar__excerpt").hasText("Pinned excerpt 0");

    // the pinned message (id 200) is edited
    await publishToMessageBus(`/chat/${this.channel.id}`, {
      type: "edit",
      chat_message: { id: 200, message: "edited", excerpt: "Edited excerpt" },
    });
    await settled();

    assert
      .dom(".chat-pinned-bar__excerpt")
      .hasText("Edited excerpt", "reflects the edited message");
  });

  test("ignores edits to messages that are not pinned", async function (assert) {
    this.channel.pinnedMessagesCount = 1;
    pretender.get(`/chat/api/channels/${this.channel.id}/pins`, () =>
      pinResponse(this.channel, 1)
    );

    await render(
      <template>
        <ChatPinnedMessageBar
          @channel={{this.channel}}
          @onJumpToMessage={{this.noop}}
        />
      </template>
    );

    // a different (unpinned) message is edited
    await publishToMessageBus(`/chat/${this.channel.id}`, {
      type: "edit",
      chat_message: { id: 999, message: "x", excerpt: "Should not appear" },
    });
    await settled();

    assert.dom(".chat-pinned-bar__excerpt").hasText("Pinned excerpt 0");
  });

  test("hides the bar when dismissed above the newest pin", async function (assert) {
    this.channel.pinnedMessagesCount = 1;
    pretender.get(`/chat/api/channels/${this.channel.id}/pins`, () =>
      dismissablePinResponse(100)
    );

    await render(
      <template>
        <ChatPinnedMessageBar
          @channel={{this.channel}}
          @onJumpToMessage={{this.noop}}
        />
      </template>
    );

    assert.dom(".chat-pinned-bar").doesNotHaveClass("--dismissed");

    this.channel.pinsDismissedAboveId = 100; // the newest pin's id
    await settled();

    assert.dom(".chat-pinned-bar").hasClass("--dismissed");
  });

  test("reappears once a pin newer than the dismissed one is added", async function (assert) {
    let pinId = 100;
    this.channel.pinnedMessagesCount = 1;
    this.channel.pinsDismissedAboveId = 100;
    pretender.get(`/chat/api/channels/${this.channel.id}/pins`, () =>
      dismissablePinResponse(pinId)
    );

    await render(
      <template>
        <ChatPinnedMessageBar
          @channel={{this.channel}}
          @onJumpToMessage={{this.noop}}
        />
      </template>
    );

    assert
      .dom(".chat-pinned-bar")
      .hasClass("--dismissed", "stays hidden while no newer pin exists");

    // a newer pin (higher id) is added
    pinId = 101;
    await publishToMessageBus(`/chat/${this.channel.id}`, {
      type: "pin",
      chat_message_id: 201,
    });
    await settled();

    assert
      .dom(".chat-pinned-bar")
      .doesNotHaveClass("--dismissed", "reappears for the newer pin");
    assert.strictEqual(
      this.channel.pinsDismissedAboveId,
      null,
      "clears the stale dismissal so the navbar re-show button doesn't linger"
    );
  });

  test("stays dismissed after reload via stored state", async function (assert) {
    // simulate a previous dismissal persisted to local storage
    const store = new KeyValueStore(STORE_NAMESPACE);
    store.setObject({ key: String(this.channel.id), value: 100 });

    this.channel.pinnedMessagesCount = 1;
    pretender.get(`/chat/api/channels/${this.channel.id}/pins`, () =>
      dismissablePinResponse(100)
    );

    await render(
      <template>
        <ChatPinnedMessageBar
          @channel={{this.channel}}
          @onJumpToMessage={{this.noop}}
        />
      </template>
    );

    assert.dom(".chat-pinned-bar").hasClass("--dismissed");
  });

  test("pin managers bypass a stored dismissal", async function (assert) {
    // a dismissal recorded before the user could manage pins
    const store = new KeyValueStore(STORE_NAMESPACE);
    store.setObject({ key: String(this.channel.id), value: 100 });
    this.channel.meta.can_manage_pins = true;

    this.channel.pinnedMessagesCount = 1;
    pretender.get(`/chat/api/channels/${this.channel.id}/pins`, () =>
      dismissablePinResponse(100)
    );

    await render(
      <template>
        <ChatPinnedMessageBar
          @channel={{this.channel}}
          @onJumpToMessage={{this.noop}}
        />
      </template>
    );

    assert
      .dom(".chat-pinned-bar")
      .doesNotHaveClass("--dismissed", "managers always see the bar");
  });

  test("stays dismissed when the dismissed pin is unpinned", async function (assert) {
    let ids = [101, 100]; // newest-first
    this.channel.pinnedMessagesCount = 2;
    this.channel.pinsDismissedAboveId = 101;
    pretender.get(`/chat/api/channels/${this.channel.id}/pins`, () =>
      pinsResponse(ids)
    );

    await render(
      <template>
        <ChatPinnedMessageBar
          @channel={{this.channel}}
          @onJumpToMessage={{this.noop}}
        />
      </template>
    );

    assert.dom(".chat-pinned-bar").hasClass("--dismissed");

    // the newest pin is unpinned, leaving only an older (lower-id) pin
    ids = [100];
    await publishToMessageBus(`/chat/${this.channel.id}`, {
      type: "unpin",
      chat_message_id: 301,
    });
    await settled();

    assert
      .dom(".chat-pinned-bar")
      .hasClass("--dismissed", "stays hidden — a removal is not a new pin");
  });

  test("uses the highest pin id, not the first pin, for dismissal", async function (assert) {
    // pins[0] is first by display order but has a LOWER id than another pin
    // (e.g. created_at not monotonic with id) — the bar must compare the max id
    this.channel.pinnedMessagesCount = 2;
    this.channel.pinsDismissedAboveId = 5;
    pretender.get(`/chat/api/channels/${this.channel.id}/pins`, () =>
      pinsResponse([5, 100])
    );

    await render(
      <template>
        <ChatPinnedMessageBar
          @channel={{this.channel}}
          @onJumpToMessage={{this.noop}}
        />
      </template>
    );

    assert
      .dom(".chat-pinned-bar")
      .doesNotHaveClass(
        "--dismissed",
        "shown because a pin with a higher id than the dismissed value exists"
      );
  });
});
