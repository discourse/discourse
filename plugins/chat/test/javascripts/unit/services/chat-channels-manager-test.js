import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import {
  CHAT_CHANNEL_LIST_FILTERS,
  CHAT_CHANNEL_LIST_SORTS,
} from "discourse/plugins/chat/discourse/lib/chat-constants";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import UserChatChannelMembership from "discourse/plugins/chat/discourse/models/user-chat-channel-membership";

module("Unit | Service | chat-channels-manager", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.subject = getOwner(this).lookup("service:chat-channels-manager");
    this.fabricators = new ChatFabricators(getOwner(this));
  });

  module("#sortChannelsByActivity with starred channels", function () {
    test("prioritizes starred channels over unstarred", function (assert) {
      const channelA = this.fabricators.channel({
        chatable: this.fabricators.coreFabricators.category({
          slug: "channel-a",
        }),
      });
      const channelB = this.fabricators.channel({
        chatable: this.fabricators.coreFabricators.category({
          slug: "channel-b",
        }),
      });

      channelA.currentUserMembership = UserChatChannelMembership.create({
        following: true,
        starred: true,
      });
      channelB.currentUserMembership = UserChatChannelMembership.create({
        following: true,
        starred: false,
      });

      this.subject.store(channelA);
      this.subject.store(channelB);

      const result = this.subject.publicMessageChannels;

      assert.strictEqual(
        result[0].id,
        channelA.id,
        "starred channel comes first"
      );
      assert.strictEqual(
        result[1].id,
        channelB.id,
        "unstarred channel comes second"
      );
    });

    test("sorts starred channels alphabetically by slug", function (assert) {
      const channelC = this.fabricators.channel({
        chatable: this.fabricators.coreFabricators.category({
          slug: "channel-c",
        }),
      });
      const channelA = this.fabricators.channel({
        chatable: this.fabricators.coreFabricators.category({
          slug: "channel-a",
        }),
      });
      const channelB = this.fabricators.channel({
        chatable: this.fabricators.coreFabricators.category({
          slug: "channel-b",
        }),
      });

      channelC.currentUserMembership = UserChatChannelMembership.create({
        following: true,
        starred: true,
      });
      channelA.currentUserMembership = UserChatChannelMembership.create({
        following: true,
        starred: true,
      });
      channelB.currentUserMembership = UserChatChannelMembership.create({
        following: true,
        starred: true,
      });

      this.subject.store(channelC);
      this.subject.store(channelA);
      this.subject.store(channelB);

      const result = this.subject.publicMessageChannels;

      assert.strictEqual(
        result[0].slug,
        "channel-a",
        "first starred channel is A"
      );
      assert.strictEqual(
        result[1].slug,
        "channel-b",
        "second starred channel is B"
      );
      assert.strictEqual(
        result[2].slug,
        "channel-c",
        "third starred channel is C"
      );
    });

    test("keeps unstarred channels sorted by activity after starred ones", function (assert) {
      const starredChannel = this.fabricators.channel({
        chatable: this.fabricators.coreFabricators.category({
          slug: "starred-channel",
        }),
      });
      const unstarredChannel = this.fabricators.channel({
        chatable: this.fabricators.coreFabricators.category({
          slug: "unstarred-channel",
        }),
      });

      starredChannel.currentUserMembership = UserChatChannelMembership.create({
        following: true,
        starred: true,
      });
      unstarredChannel.currentUserMembership = UserChatChannelMembership.create(
        {
          following: true,
          starred: false,
        }
      );

      this.subject.store(unstarredChannel);
      this.subject.store(starredChannel);

      const result = this.subject.publicMessageChannels;

      assert.strictEqual(
        result[0].id,
        starredChannel.id,
        "starred channel is first"
      );
      assert.strictEqual(
        result[1].id,
        unstarredChannel.id,
        "unstarred channel is after starred"
      );
    });
  });

  module("#unstarredPublicMessageChannelsByActivity", function () {
    test("excludes starred channels", function (assert) {
      const starredChannel = this.fabricators.channel({
        chatable: this.fabricators.coreFabricators.category({
          slug: "starred-channel",
        }),
      });
      const unstarredChannel = this.fabricators.channel({
        chatable: this.fabricators.coreFabricators.category({
          slug: "unstarred-channel",
        }),
      });

      starredChannel.currentUserMembership = UserChatChannelMembership.create({
        following: true,
        starred: true,
      });
      unstarredChannel.currentUserMembership = UserChatChannelMembership.create(
        {
          following: true,
          starred: false,
        }
      );

      this.subject.store(starredChannel);
      this.subject.store(unstarredChannel);

      const result = this.subject.unstarredPublicMessageChannelsByActivity;

      assert.strictEqual(result.length, 1, "returns only unstarred channels");
      assert.strictEqual(
        result[0].id,
        unstarredChannel.id,
        "returns the unstarred channel"
      );
    });

    test("sorts unstarred channels by activity with unreads first", function (assert) {
      const channelWithUnread = this.fabricators.channel({
        chatable: this.fabricators.coreFabricators.category({
          slug: "channel-with-unread",
        }),
      });
      const channelNoUnread = this.fabricators.channel({
        chatable: this.fabricators.coreFabricators.category({
          slug: "channel-no-unread",
        }),
      });

      channelWithUnread.currentUserMembership =
        UserChatChannelMembership.create({
          following: true,
          starred: false,
        });
      channelNoUnread.currentUserMembership = UserChatChannelMembership.create({
        following: true,
        starred: false,
      });

      channelWithUnread.tracking.unreadCount = 5;
      channelNoUnread.tracking.unreadCount = 0;

      this.subject.store(channelNoUnread);
      this.subject.store(channelWithUnread);

      const result = this.subject.unstarredPublicMessageChannelsByActivity;

      assert.strictEqual(
        result[0].id,
        channelWithUnread.id,
        "channel with unreads comes first"
      );
      assert.strictEqual(
        result[1].id,
        channelNoUnread.id,
        "channel without unreads comes second"
      );
    });
  });

  module("#starredChannelsByActivity", function () {
    test("sorts starred channels with unreads first", function (assert) {
      const channelWithUnread = this.fabricators.channel({
        chatable: this.fabricators.coreFabricators.category({
          slug: "channel-with-unread",
        }),
      });
      const channelNoUnread = this.fabricators.channel({
        chatable: this.fabricators.coreFabricators.category({
          slug: "channel-no-unread",
        }),
      });

      channelWithUnread.currentUserMembership =
        UserChatChannelMembership.create({
          following: true,
          starred: true,
        });
      channelNoUnread.currentUserMembership = UserChatChannelMembership.create({
        following: true,
        starred: true,
      });

      channelWithUnread.tracking.unreadCount = 5;
      channelNoUnread.tracking.unreadCount = 0;

      this.subject.store(channelNoUnread);
      this.subject.store(channelWithUnread);

      const result = this.subject.starredChannelsByActivity;

      assert.strictEqual(
        result[0].id,
        channelWithUnread.id,
        "channel with unreads comes first"
      );
      assert.strictEqual(
        result[1].id,
        channelNoUnread.id,
        "channel without unreads comes second"
      );
    });

    test("includes both public and DM starred channels", function (assert) {
      const publicChannel = this.fabricators.channel({
        chatable: this.fabricators.coreFabricators.category({
          slug: "public",
        }),
      });
      const dmChannel = this.fabricators.channel({
        chatable: this.fabricators.directMessage(),
        title: "DM User",
      });

      publicChannel.currentUserMembership = UserChatChannelMembership.create({
        following: true,
        starred: true,
      });
      dmChannel.currentUserMembership = UserChatChannelMembership.create({
        following: true,
        starred: true,
      });

      this.subject.store(publicChannel);
      this.subject.store(dmChannel);

      const result = this.subject.starredChannelsByActivity;

      assert.strictEqual(result.length, 2, "returns both channels");
    });

    test("prioritizes unread status over channel type", function (assert) {
      const readPublicChannel = this.fabricators.channel({
        chatable: this.fabricators.coreFabricators.category({
          slug: "read-public",
        }),
      });
      const unreadDmChannel = this.fabricators.channel({
        chatable: this.fabricators.directMessage(),
        title: "Unread DM",
      });

      readPublicChannel.currentUserMembership =
        UserChatChannelMembership.create({
          following: true,
          starred: true,
        });
      unreadDmChannel.currentUserMembership = UserChatChannelMembership.create({
        following: true,
        starred: true,
      });

      readPublicChannel.tracking.unreadCount = 0;
      unreadDmChannel.tracking.unreadCount = 3;

      this.subject.store(readPublicChannel);
      this.subject.store(unreadDmChannel);

      const result = this.subject.starredChannelsByActivity;

      assert.strictEqual(
        result[0].id,
        unreadDmChannel.id,
        "unread DM comes before read public channel"
      );
      assert.strictEqual(
        result[1].id,
        readPublicChannel.id,
        "read public channel comes after unread DM"
      );
    });

    test("sorts unread public channels before unread DMs", function (assert) {
      const unreadPublicChannel = this.fabricators.channel({
        chatable: this.fabricators.coreFabricators.category({
          slug: "unread-public",
        }),
      });
      const unreadDmChannel = this.fabricators.channel({
        chatable: this.fabricators.directMessage(),
        title: "Unread DM",
      });

      unreadPublicChannel.currentUserMembership =
        UserChatChannelMembership.create({
          following: true,
          starred: true,
        });
      unreadDmChannel.currentUserMembership = UserChatChannelMembership.create({
        following: true,
        starred: true,
      });

      unreadPublicChannel.tracking.unreadCount = 2;
      unreadDmChannel.tracking.unreadCount = 5;

      this.subject.store(unreadDmChannel);
      this.subject.store(unreadPublicChannel);

      const result = this.subject.starredChannelsByActivity;

      assert.strictEqual(
        result[0].id,
        unreadPublicChannel.id,
        "unread public channel comes first"
      );
      assert.strictEqual(
        result[1].id,
        unreadDmChannel.id,
        "unread DM comes second"
      );
    });

    test("sorts read public channels before read DMs", function (assert) {
      const readPublicChannel = this.fabricators.channel({
        chatable: this.fabricators.coreFabricators.category({
          slug: "read-public",
        }),
      });
      const readDmChannel = this.fabricators.channel({
        chatable: this.fabricators.directMessage(),
        title: "Read DM",
      });

      readPublicChannel.currentUserMembership =
        UserChatChannelMembership.create({
          following: true,
          starred: true,
        });
      readDmChannel.currentUserMembership = UserChatChannelMembership.create({
        following: true,
        starred: true,
      });

      readPublicChannel.tracking.unreadCount = 0;
      readDmChannel.tracking.unreadCount = 0;

      this.subject.store(readDmChannel);
      this.subject.store(readPublicChannel);

      const result = this.subject.starredChannelsByActivity;

      assert.strictEqual(
        result[0].id,
        readPublicChannel.id,
        "read public channel comes first"
      );
      assert.strictEqual(
        result[1].id,
        readDmChannel.id,
        "read DM comes second"
      );
    });

    test("complete ordering: unread public, unread DM, read public, read DM", function (assert) {
      const readPublicChannel = this.fabricators.channel({
        chatable: this.fabricators.coreFabricators.category({
          slug: "read-public",
        }),
      });
      const unreadPublicChannel = this.fabricators.channel({
        chatable: this.fabricators.coreFabricators.category({
          slug: "unread-public",
        }),
      });
      const readDmChannel = this.fabricators.channel({
        chatable: this.fabricators.directMessage(),
        title: "Read DM",
      });
      const unreadDmChannel = this.fabricators.channel({
        chatable: this.fabricators.directMessage(),
        title: "Unread DM",
      });

      readPublicChannel.currentUserMembership =
        UserChatChannelMembership.create({
          following: true,
          starred: true,
        });
      unreadPublicChannel.currentUserMembership =
        UserChatChannelMembership.create({
          following: true,
          starred: true,
        });
      readDmChannel.currentUserMembership = UserChatChannelMembership.create({
        following: true,
        starred: true,
      });
      unreadDmChannel.currentUserMembership = UserChatChannelMembership.create({
        following: true,
        starred: true,
      });

      readPublicChannel.tracking.unreadCount = 0;
      unreadPublicChannel.tracking.unreadCount = 2;
      readDmChannel.tracking.unreadCount = 0;
      unreadDmChannel.tracking.unreadCount = 3;

      this.subject.store(readDmChannel);
      this.subject.store(unreadDmChannel);
      this.subject.store(readPublicChannel);
      this.subject.store(unreadPublicChannel);

      const result = this.subject.starredChannelsByActivity;

      assert.strictEqual(result.length, 4, "returns all 4 channels");
      assert.strictEqual(
        result[0].id,
        unreadPublicChannel.id,
        "1st: unread public channel"
      );
      assert.strictEqual(result[1].id, unreadDmChannel.id, "2nd: unread DM");
      assert.strictEqual(
        result[2].id,
        readPublicChannel.id,
        "3rd: read public channel"
      );
      assert.strictEqual(result[3].id, readDmChannel.id, "4th: read DM");
    });
  });

  module("#sortDirectMessageChannels with starred channels", function () {
    test("prioritizes starred DM channels over unstarred", function (assert) {
      const dmA = this.fabricators.channel({
        chatable: this.fabricators.directMessage(),
        title: "Alice",
      });
      const dmB = this.fabricators.channel({
        chatable: this.fabricators.directMessage(),
        title: "Bob",
      });

      dmA.currentUserMembership = UserChatChannelMembership.create({
        following: true,
        starred: true,
      });
      dmB.currentUserMembership = UserChatChannelMembership.create({
        following: true,
        starred: false,
      });

      this.subject.store(dmA);
      this.subject.store(dmB);

      const result = this.subject.directMessageChannels;

      assert.strictEqual(
        result[0].id,
        dmA.id,
        "starred DM channel comes first"
      );
      assert.strictEqual(
        result[1].id,
        dmB.id,
        "unstarred DM channel comes second"
      );
    });

    test("sorts starred DM channels alphabetically by title", function (assert) {
      const dmCharlie = this.fabricators.channel({
        chatable: this.fabricators.directMessage(),
        title: "Charlie",
      });
      const dmAlice = this.fabricators.channel({
        chatable: this.fabricators.directMessage(),
        title: "Alice",
      });
      const dmBob = this.fabricators.channel({
        chatable: this.fabricators.directMessage(),
        title: "Bob",
      });

      dmCharlie.currentUserMembership = UserChatChannelMembership.create({
        following: true,
        starred: true,
      });
      dmAlice.currentUserMembership = UserChatChannelMembership.create({
        following: true,
        starred: true,
      });
      dmBob.currentUserMembership = UserChatChannelMembership.create({
        following: true,
        starred: true,
      });

      this.subject.store(dmCharlie);
      this.subject.store(dmAlice);
      this.subject.store(dmBob);

      const result = this.subject.directMessageChannels;

      assert.strictEqual(result[0].title, "Alice", "first starred DM is Alice");
      assert.strictEqual(result[1].title, "Bob", "second starred DM is Bob");
      assert.strictEqual(
        result[2].title,
        "Charlie",
        "third starred DM is Charlie"
      );
    });

    test("keeps unstarred DM channels sorted by activity after starred ones", function (assert) {
      const starredDM = this.fabricators.channel({
        chatable: this.fabricators.directMessage(),
        title: "Starred User",
      });
      const unstarredDM = this.fabricators.channel({
        chatable: this.fabricators.directMessage(),
        title: "Unstarred User",
      });

      starredDM.currentUserMembership = UserChatChannelMembership.create({
        following: true,
        starred: true,
      });
      unstarredDM.currentUserMembership = UserChatChannelMembership.create({
        following: true,
        starred: false,
      });

      this.subject.store(unstarredDM);
      this.subject.store(starredDM);

      const result = this.subject.directMessageChannels;

      assert.strictEqual(
        result[0].id,
        starredDM.id,
        "starred DM channel is first"
      );
      assert.strictEqual(
        result[1].id,
        unstarredDM.id,
        "unstarred DM channel is after starred"
      );
    });
  });

  module("#sidebarPublicMessageChannels", function (nestedHooks) {
    nestedHooks.beforeEach(function () {
      this.preferences = getOwner(this).lookup(
        "service:chat-channel-list-preferences"
      );
      this.buildChannel = ({
        id,
        slug,
        createdAt,
        unreadCount = 0,
        mentionCount = 0,
        watchedThreadsUnreadCount = 0,
        muted = false,
      }) => {
        const channel = this.fabricators.channel({
          id,
          chatable: this.fabricators.coreFabricators.category({ slug }),
        });
        channel.currentUserMembership = UserChatChannelMembership.create({
          following: true,
          starred: false,
          muted,
        });
        channel.lastMessage = this.fabricators.message({
          id: id * 10,
          channel,
          created_at: createdAt,
        });
        channel.tracking.unreadCount = unreadCount;
        channel.tracking.mentionCount = mentionCount;
        channel.tracking.watchedThreadsUnreadCount = watchedThreadsUnreadCount;
        this.subject.store(channel);
        return channel;
      };
    });

    test("sorts channels alphabetically by default", function (assert) {
      this.buildChannel({ id: 1, slug: "zulu", createdAt: "2026-09-03" });
      this.buildChannel({ id: 2, slug: "alpha", createdAt: "2026-09-01" });

      assert.deepEqual(
        this.subject.sidebarPublicMessageChannels.map(
          (channel) => channel.slug
        ),
        ["alpha", "zulu"],
        "channels are sorted by slug"
      );
    });

    test("sorts channels by recent activity", function (assert) {
      this.preferences.sort = CHAT_CHANNEL_LIST_SORTS.RECENT_ACTIVITY;
      this.buildChannel({ id: 1, slug: "older", createdAt: "2026-09-01" });
      this.buildChannel({ id: 2, slug: "newer", createdAt: "2026-09-03" });
      const emptyChannel = this.buildChannel({
        id: 3,
        slug: "empty",
        createdAt: "2026-09-04",
      });
      emptyChannel.lastMessage = null;

      assert.deepEqual(
        this.subject.sidebarPublicMessageChannels.map(
          (channel) => channel.slug
        ),
        ["newer", "older", "empty"],
        "newer channels are first and empty channels are last"
      );
    });

    test("sorts urgent, unread, and read channels by priority", function (assert) {
      this.preferences.sort = CHAT_CHANNEL_LIST_SORTS.PRIORITY;
      this.buildChannel({ id: 1, slug: "read", createdAt: "2026-09-03" });
      this.buildChannel({
        id: 2,
        slug: "unread",
        createdAt: "2026-09-01",
        unreadCount: 1,
      });
      this.buildChannel({
        id: 3,
        slug: "urgent",
        createdAt: "2026-08-30",
        mentionCount: 1,
      });

      assert.deepEqual(
        this.subject.sidebarPublicMessageChannels.map(
          (channel) => channel.slug
        ),
        ["urgent", "unread", "read"],
        "priority groups are ordered"
      );
    });

    test("filters channels by recent activity", function (assert) {
      const clock = sinon.useFakeTimers(new Date("2026-09-03T12:00:00Z"));

      try {
        this.preferences.filter = CHAT_CHANNEL_LIST_FILTERS.ACTIVE;
        this.buildChannel({
          id: 1,
          slug: "active",
          createdAt: "2026-08-05T12:00:00Z",
        });
        this.buildChannel({
          id: 2,
          slug: "boundary",
          createdAt: "2026-08-04T12:00:00Z",
        });
        this.buildChannel({
          id: 3,
          slug: "inactive",
          createdAt: "2026-08-03T11:59:59Z",
        });

        assert.deepEqual(
          this.subject.sidebarPublicMessageChannels.map(
            (channel) => channel.slug
          ),
          ["active", "boundary"],
          "the 30-day boundary is inclusive"
        );
      } finally {
        clock.restore();
      }
    });

    test("keeps the active channel visible when it does not match", function (assert) {
      this.preferences.filter = CHAT_CHANNEL_LIST_FILTERS.UNREAD;
      const activeChannel = this.buildChannel({
        id: 1,
        slug: "active",
        createdAt: "2026-09-03",
      });
      const chat = getOwner(this).lookup("service:chat");
      const chatStateManager = getOwner(this).lookup(
        "service:chat-state-manager"
      );
      chat.activeChannel = activeChannel;
      chatStateManager.isDrawerExpanded = true;

      assert.deepEqual(
        this.subject.sidebarPublicMessageChannels.map(
          (channel) => channel.slug
        ),
        ["active"],
        "the channel being viewed remains available"
      );
    });

    test("filters unread and mention channels and excludes muted activity", function (assert) {
      this.buildChannel({ id: 1, slug: "read", createdAt: "2026-09-03" });
      this.buildChannel({
        id: 2,
        slug: "unread",
        createdAt: "2026-09-02",
        unreadCount: 1,
      });
      this.buildChannel({
        id: 3,
        slug: "mention",
        createdAt: "2026-09-01",
        mentionCount: 1,
      });
      this.buildChannel({
        id: 4,
        slug: "muted",
        createdAt: "2026-09-03",
        mentionCount: 1,
        muted: true,
      });

      this.preferences.filter = CHAT_CHANNEL_LIST_FILTERS.UNREAD;
      assert.deepEqual(
        this.subject.sidebarPublicMessageChannels.map(
          (channel) => channel.slug
        ),
        ["mention", "unread"],
        "all visible unread activity is included"
      );

      this.preferences.filter = CHAT_CHANNEL_LIST_FILTERS.MENTIONS;
      assert.deepEqual(
        this.subject.sidebarPublicMessageChannels.map(
          (channel) => channel.slug
        ),
        ["mention"],
        "only non-muted urgent activity is included"
      );
    });

    test("falls back to showing channels for an unknown filter", function (assert) {
      this.preferences.filter = "unknown";
      this.buildChannel({ id: 1, slug: "read", createdAt: "2026-09-03" });

      assert.deepEqual(
        this.subject.sidebarPublicMessageChannels.map(
          (channel) => channel.slug
        ),
        ["read"],
        "an invalid persisted value does not hide the channel list"
      );
    });
  });

  module("#sidebarDirectMessageChannels", function (nestedHooks) {
    nestedHooks.beforeEach(function () {
      this.preferences = getOwner(this).lookup(
        "service:chat-channel-list-preferences"
      );
      this.buildDirectMessageChannel = ({
        id,
        title,
        createdAt = "2026-09-03",
        unreadCount = 0,
        mentionCount = 0,
        muted = false,
        starred = false,
      }) => {
        const channel = this.fabricators.channel({
          id,
          chatable: this.fabricators.directMessage(),
          title,
        });
        channel.currentUserMembership = UserChatChannelMembership.create({
          following: true,
          muted,
          starred,
        });
        channel.lastMessage = this.fabricators.message({
          id: id * 10,
          channel,
          created_at: createdAt,
        });
        channel.tracking.unreadCount = unreadCount;
        channel.tracking.mentionCount = mentionCount;
        this.subject.store(channel);
        return channel;
      };
    });

    test("sorts direct messages alphabetically by title", function (assert) {
      this.buildDirectMessageChannel({ id: 1, title: "Zulu" });
      this.buildDirectMessageChannel({ id: 2, title: "Alpha" });

      assert.deepEqual(
        this.subject.sidebarDirectMessageChannels.map(
          (channel) => channel.title
        ),
        ["Alpha", "Zulu"],
        "direct messages use their titles for alphabetical sorting"
      );
    });

    test("keeps an active direct message within the sidebar limit", function (assert) {
      for (let index = 0; index < 50; index++) {
        this.buildDirectMessageChannel({
          id: index + 1,
          title: `Channel ${String(index).padStart(2, "0")}`,
        });
      }
      const activeChannel = this.buildDirectMessageChannel({
        id: 51,
        title: "Zulu",
      });
      const chat = getOwner(this).lookup("service:chat");
      const chatStateManager = getOwner(this).lookup(
        "service:chat-state-manager"
      );
      chat.activeChannel = activeChannel;
      chatStateManager.isDrawerExpanded = true;

      assert.strictEqual(
        this.subject.sidebarDirectMessageChannels.length,
        50,
        "the sidebar limit remains enforced"
      );
      assert.true(
        this.subject.sidebarDirectMessageChannels.includes(activeChannel),
        "the direct message being viewed remains available"
      );
    });

    test("applies non-default sorting to starred channels", function (assert) {
      this.buildDirectMessageChannel({
        id: 1,
        title: "Older",
        createdAt: "2026-09-01",
        starred: true,
      });
      this.buildDirectMessageChannel({
        id: 2,
        title: "Newer",
        createdAt: "2026-09-03",
        starred: true,
      });
      this.preferences.sort = CHAT_CHANNEL_LIST_SORTS.RECENT_ACTIVITY;

      assert.deepEqual(
        this.subject.sidebarStarredChannels.map((channel) => channel.title),
        ["Newer", "Older"],
        "starred channels honor the selected activity sort"
      );
    });

    test("filters unstarred and starred direct messages by unread activity", function (assert) {
      this.buildDirectMessageChannel({ id: 1, title: "Read" });
      this.buildDirectMessageChannel({
        id: 2,
        title: "Unread",
        unreadCount: 1,
      });
      this.buildDirectMessageChannel({
        id: 3,
        title: "Muted",
        unreadCount: 1,
        muted: true,
      });
      this.buildDirectMessageChannel({
        id: 4,
        title: "Starred read",
        starred: true,
      });
      this.buildDirectMessageChannel({
        id: 5,
        title: "Starred unread",
        mentionCount: 1,
        starred: true,
      });
      this.preferences.filter = CHAT_CHANNEL_LIST_FILTERS.UNREAD;

      assert.deepEqual(
        this.subject.sidebarDirectMessageChannels.map(
          (channel) => channel.title
        ),
        ["Unread"],
        "only non-muted unstarred direct messages with activity remain"
      );
      assert.deepEqual(
        this.subject.sidebarStarredChannels.map((channel) => channel.title),
        ["Starred unread"],
        "the unread filter also applies to starred direct messages"
      );
    });
  });
});
