import { module, test } from "qunit";
import {
  DirectMessageLink,
  TextChannelLink,
} from "../../../discourse/lib/channel-links.js";

function channel({ unread = 0, mentions = 0, threads = 0, users = [] } = {}) {
  return {
    id: 4,
    slugifiedTitle: "hangout",
    title: "hangout",
    escapedTitle: "hangout",
    tracking: {
      unreadCount: unread,
      mentionCount: mentions,
      watchedThreadsUnreadCount: threads,
    },
    chatable: { users },
    currentUserMembership: {},
  };
}

module("Unit | Lib | channel-links", function () {
  test("a text channel shows a mention count, or a dot when only unread", function (assert) {
    const quiet = new TextChannelLink({ channel: channel() });
    assert.strictEqual(quiet.badgeText, null);
    assert.strictEqual(quiet.suffixValue, undefined);
    assert.false(quiet.classNames.includes("concord-channel--unread"));

    const unread = new TextChannelLink({ channel: channel({ unread: 3 }) });
    assert.strictEqual(unread.badgeText, null);
    assert.strictEqual(unread.suffixValue, "circle");
    assert.true(unread.classNames.includes("concord-channel--unread"));

    const mentioned = new TextChannelLink({
      channel: channel({ unread: 3, mentions: 2 }),
    });
    assert.strictEqual(mentioned.badgeText, "2");
    assert.strictEqual(mentioned.suffixValue, undefined);
  });

  test("a DM counts its unread messages", function (assert) {
    const link = new DirectMessageLink({
      channel: channel({
        unread: 5,
        users: [{ avatar_template: "/a/{size}.png" }],
      }),
    });

    assert.strictEqual(link.name, "dm-4");
    assert.strictEqual(link.channelKey, "dm:4");
    assert.strictEqual(link.badgeText, "5");
    assert.strictEqual(link.prefixType, "image");
  });

  test("a group DM gets a group icon", function (assert) {
    const link = new DirectMessageLink({
      channel: channel({ users: [{}, {}] }),
    });

    assert.strictEqual(link.prefixType, "icon");
    assert.strictEqual(link.prefixValue, "user-group");
    assert.strictEqual(link.badgeText, null);
  });
});
