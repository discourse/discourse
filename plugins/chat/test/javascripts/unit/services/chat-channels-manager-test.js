import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
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

  module("#toggleStarred", function (nestedHooks) {
    nestedHooks.beforeEach(function () {
      this.channel = this.fabricators.channel();
      this.channel.currentUserMembership = UserChatChannelMembership.create({
        following: true,
        starred: false,
      });
    });

    test("guards pending changes and persists the optimistic value", async function (assert) {
      const channel = this.channel;
      const membership = channel.currentUserMembership;
      const requests = [];
      pretender.put(
        `/chat/api/channels/${channel.id}/memberships/me`,
        (request) => {
          requests.push(
            new URLSearchParams(request.requestBody).get("starred")
          );
          return response(200, {});
        }
      );
      let finishClosing;
      const closing = new Promise((resolve) => {
        finishClosing = resolve;
      });

      const update = this.subject.toggleStarred(channel, {
        beforeUpdate: () => closing,
      });

      assert.true(
        this.subject.isUpdatingStarred(channel),
        "closing the menu is guarded"
      );
      assert.false(
        membership.starred,
        "the row stays in place until the menu closes"
      );
      await this.subject.toggleStarred(channel);
      assert.strictEqual(
        requests.length,
        0,
        "a second caller cannot start another update"
      );

      finishClosing();
      await closing;
      assert.true(
        membership.starred,
        "the membership updates before the request completes"
      );
      await update;

      assert.deepEqual(requests, ["true"], "one starred update is persisted");
      assert.false(
        this.subject.isUpdatingStarred(channel),
        "the guard clears after saving"
      );

      await this.subject.toggleStarred(channel);
      assert.false(
        membership.starred,
        "the channel can subsequently be unstarred"
      );
      assert.deepEqual(
        requests,
        ["true", "false"],
        "the second change is persisted"
      );
    });

    test("rolls back failed saves and permits retrying", async function (assert) {
      const channel = this.channel;
      pretender.put(`/chat/api/channels/${channel.id}/memberships/me`, () =>
        response(422, { errors: ["Unable to star channel"] })
      );

      await this.subject.toggleStarred(channel);

      assert.false(
        channel.currentUserMembership.starred,
        "the previous membership is restored"
      );
      assert.false(
        this.subject.isUpdatingStarred(channel),
        "the failed request releases the guard"
      );

      pretender.put(`/chat/api/channels/${channel.id}/memberships/me`, () =>
        response(200, {})
      );
      await this.subject.toggleStarred(channel);
      assert.true(channel.currentUserMembership.starred, "retrying succeeds");
    });

    test("releases the guard when closing the menu fails", async function (assert) {
      const channel = this.channel;
      let requests = 0;
      pretender.put(`/chat/api/channels/${channel.id}/memberships/me`, () => {
        requests++;
        return response(200, {});
      });

      await this.subject.toggleStarred(channel, {
        beforeUpdate: () =>
          Promise.reject({ errors: ["Unable to close menu"] }),
      });

      assert.false(
        channel.currentUserMembership.starred,
        "the membership was not changed"
      );
      assert.strictEqual(requests, 0, "no request was sent");
      assert.false(
        this.subject.isUpdatingStarred(channel),
        "the close failure releases the guard"
      );

      await this.subject.toggleStarred(channel);
      assert.true(
        channel.currentUserMembership.starred,
        "a later attempt succeeds"
      );
      assert.strictEqual(requests, 1, "the later attempt is persisted");
    });
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
      this.preferences.channelsSort = CHAT_CHANNEL_LIST_SORTS.RECENT_ACTIVITY;
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
      this.preferences.channelsSort = CHAT_CHANNEL_LIST_SORTS.PRIORITY;
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
        this.preferences.channelsFilter = CHAT_CHANNEL_LIST_FILTERS.ACTIVE;
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
      this.preferences.channelsFilter = CHAT_CHANNEL_LIST_FILTERS.UNREAD;
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

      this.preferences.channelsFilter = CHAT_CHANNEL_LIST_FILTERS.UNREAD;
      assert.deepEqual(
        this.subject.sidebarPublicMessageChannels.map(
          (channel) => channel.slug
        ),
        ["mention", "unread"],
        "all visible unread activity is included"
      );

      this.preferences.channelsFilter = CHAT_CHANNEL_LIST_FILTERS.MENTIONS;
      assert.deepEqual(
        this.subject.sidebarPublicMessageChannels.map(
          (channel) => channel.slug
        ),
        ["mention"],
        "only non-muted urgent activity is included"
      );
    });

    test("falls back to showing channels for an unknown filter", function (assert) {
      this.preferences.channelsFilter = "unknown";
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
      this.preferences.dmsSort = CHAT_CHANNEL_LIST_SORTS.RECENT_ACTIVITY;

      assert.deepEqual(
        this.subject.starredChannelsByPreference.map(
          (channel) => channel.title
        ),
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
      this.preferences.dmsFilter = CHAT_CHANNEL_LIST_FILTERS.UNREAD;

      assert.deepEqual(
        this.subject.sidebarDirectMessageChannels.map(
          (channel) => channel.title
        ),
        ["Unread"],
        "only non-muted unstarred direct messages with activity remain"
      );
      assert.deepEqual(
        this.subject.starredChannelsByPreference.map(
          (channel) => channel.title
        ),
        ["Starred read", "Starred unread"],
        "the dms unread filter does not leak into the starred list"
      );
    });
  });

  module("#publicMessageChannelsByPreference", function (nestedHooks) {
    nestedHooks.beforeEach(function () {
      this.preferences = getOwner(this).lookup(
        "service:chat-channel-list-preferences"
      );
      this.buildChannel = ({
        id,
        slug,
        createdAt,
        starred = false,
        unreadCount = 0,
        mentionCount = 0,
        muted = false,
      }) => {
        const channel = this.fabricators.channel({
          id,
          chatable: this.fabricators.coreFabricators.category({ slug }),
        });
        channel.currentUserMembership = UserChatChannelMembership.create({
          following: true,
          starred,
          muted,
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

    test("includes starred channels and sorts alphabetically by default", function (assert) {
      this.buildChannel({ id: 1, slug: "zulu", createdAt: "2026-09-01" });
      this.buildChannel({ id: 2, slug: "alpha", createdAt: "2026-09-03" });
      this.buildChannel({
        id: 3,
        slug: "beta",
        createdAt: "2026-09-02",
        starred: true,
      });

      assert.deepEqual(
        this.subject.publicMessageChannelsByPreference.map(
          (channel) => channel.slug
        ),
        ["alpha", "beta", "zulu"],
        "starred channels stay in the channels list and sort by slug"
      );
    });

    test("sorts by recent activity", function (assert) {
      this.preferences.channelsSort = CHAT_CHANNEL_LIST_SORTS.RECENT_ACTIVITY;
      this.buildChannel({ id: 1, slug: "older", createdAt: "2026-09-01" });
      this.buildChannel({ id: 2, slug: "newer", createdAt: "2026-09-03" });

      assert.deepEqual(
        this.subject.publicMessageChannelsByPreference.map(
          (channel) => channel.slug
        ),
        ["newer", "older"],
        "channels with newer activity sort first"
      );
    });

    test("sorts urgent, unread, and read channels by priority", function (assert) {
      this.preferences.channelsSort = CHAT_CHANNEL_LIST_SORTS.PRIORITY;
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
        this.subject.publicMessageChannelsByPreference.map(
          (channel) => channel.slug
        ),
        ["urgent", "unread", "read"],
        "priority places urgent, then unread, then read channels"
      );
    });

    test("applies the channels filter", function (assert) {
      this.preferences.channelsFilter = CHAT_CHANNEL_LIST_FILTERS.UNREAD;
      this.buildChannel({ id: 1, slug: "read", createdAt: "2026-09-03" });
      this.buildChannel({
        id: 2,
        slug: "unreaded",
        createdAt: "2026-09-01",
        unreadCount: 1,
      });

      assert.deepEqual(
        this.subject.publicMessageChannelsByPreference.map(
          (channel) => channel.slug
        ),
        ["unreaded"],
        "read channels are hidden by the unread filter"
      );
    });
  });

  module("#directMessageChannelsByPreference", function (nestedHooks) {
    nestedHooks.beforeEach(function () {
      this.preferences = getOwner(this).lookup(
        "service:chat-channel-list-preferences"
      );
      this.buildDirectMessageChannel = ({
        id,
        title,
        createdAt = "2026-09-03",
        starred = false,
      }) => {
        const channel = this.fabricators.channel({
          id,
          chatable: this.fabricators.directMessage(),
          title,
        });
        channel.currentUserMembership = UserChatChannelMembership.create({
          following: true,
          starred,
        });
        channel.lastMessage = this.fabricators.message({
          id: id * 10,
          channel,
          created_at: createdAt,
        });
        this.subject.store(channel);
        return channel;
      };
    });

    test("includes starred channels and sorts alphabetically by title", function (assert) {
      this.buildDirectMessageChannel({ id: 1, title: "Zulu" });
      this.buildDirectMessageChannel({ id: 2, title: "Alpha" });
      this.buildDirectMessageChannel({ id: 3, title: "Beta", starred: true });

      assert.deepEqual(
        this.subject.directMessageChannelsByPreference.map(
          (channel) => channel.title
        ),
        ["Alpha", "Beta", "Zulu"],
        "starred DMs stay in the DM list and sort by title"
      );
    });

    test("sorts by recent activity with empty channels last", function (assert) {
      this.preferences.dmsSort = CHAT_CHANNEL_LIST_SORTS.RECENT_ACTIVITY;
      this.buildDirectMessageChannel({
        id: 1,
        title: "Older",
        createdAt: "2026-09-01",
      });
      this.buildDirectMessageChannel({
        id: 2,
        title: "Newer",
        createdAt: "2026-09-02",
      });
      const emptyChannel = this.buildDirectMessageChannel({
        id: 3,
        title: "Empty",
        createdAt: "2026-09-04",
      });
      emptyChannel.lastMessage = null;

      const result = this.subject.directMessageChannelsByPreference;
      assert.deepEqual(
        result.map((channel) => channel.title),
        ["Newer", "Older", "Empty"],
        "channels without a last message sort after those with activity"
      );
    });

    test("applies the dms filter", function (assert) {
      this.preferences.dmsFilter = CHAT_CHANNEL_LIST_FILTERS.UNREAD;
      const unreadDm = this.buildDirectMessageChannel({
        id: 1,
        title: "Unreaded",
      });
      unreadDm.tracking.unreadCount = 1;
      this.buildDirectMessageChannel({ id: 2, title: "Read" });

      assert.deepEqual(
        this.subject.directMessageChannelsByPreference.map(
          (channel) => channel.title
        ),
        ["Unreaded"],
        "read DMs are hidden by the unread filter"
      );
    });
  });

  module("#starredChannelsByPreference", function (nestedHooks) {
    nestedHooks.beforeEach(function () {
      this.preferences = getOwner(this).lookup(
        "service:chat-channel-list-preferences"
      );
      this.buildPublic = ({ id, slug, createdAt }) => {
        const channel = this.fabricators.channel({
          id,
          chatable: this.fabricators.coreFabricators.category({ slug }),
        });
        channel.currentUserMembership = UserChatChannelMembership.create({
          following: true,
          starred: true,
        });
        channel.lastMessage = this.fabricators.message({
          id: id * 10,
          channel,
          created_at: createdAt,
        });
        this.subject.store(channel);
        return channel;
      };
      this.buildDirectMessage = ({
        id,
        title,
        createdAt,
        mentionCount = 0,
      }) => {
        const channel = this.fabricators.channel({
          id,
          chatable: this.fabricators.directMessage(),
          title,
        });
        channel.currentUserMembership = UserChatChannelMembership.create({
          following: true,
          starred: true,
        });
        channel.lastMessage = this.fabricators.message({
          id: id * 10,
          channel,
          created_at: createdAt,
        });
        channel.tracking.mentionCount = mentionCount;
        this.subject.store(channel);
        return channel;
      };
      this.channelName = (channel) =>
        channel.isDirectMessageChannel ? channel.title : channel.slug;
    });

    test("sorts public channels then direct messages alphabetically", function (assert) {
      this.buildDirectMessage({ id: 4, title: "A dm" });
      this.buildPublic({
        id: 1,
        slug: "zulu",
        createdAt: "2026-09-03",
      });
      this.buildPublic({
        id: 2,
        slug: "alpha",
        createdAt: "2026-09-01",
      });

      assert.deepEqual(
        this.subject.starredChannelsByPreference.map(this.channelName),
        ["alpha", "zulu", "A dm"],
        "public channels precede direct messages and each group sorts by name"
      );
    });

    test("sorts by recent activity across public and direct messages", function (assert) {
      this.preferences.starredSort = CHAT_CHANNEL_LIST_SORTS.RECENT_ACTIVITY;
      this.buildPublic({
        id: 1,
        slug: "oldpub",
        createdAt: "2026-09-01",
      });
      this.buildDirectMessage({
        id: 2,
        title: "New dm",
        createdAt: "2026-09-03",
      });

      assert.deepEqual(
        this.subject.starredChannelsByPreference.map(this.channelName),
        ["New dm", "oldpub"],
        "the most recently active starred channel sorts first"
      );
    });

    test("sorts by priority with mentions first", function (assert) {
      this.preferences.starredSort = CHAT_CHANNEL_LIST_SORTS.PRIORITY;
      this.buildDirectMessage({
        id: 1,
        title: "Read dm",
        createdAt: "2026-09-03",
      });
      this.buildDirectMessage({
        id: 2,
        title: "Mentioned dm",
        createdAt: "2026-09-01",
        mentionCount: 1,
      });

      assert.deepEqual(
        this.subject.starredChannelsByPreference.map(this.channelName),
        ["Mentioned dm", "Read dm"],
        "starred channels with mentions sort first"
      );
    });

    test("applies the starred filter across public and direct messages", function (assert) {
      this.preferences.starredFilter = CHAT_CHANNEL_LIST_FILTERS.UNREAD;
      const unreadPublic = this.buildPublic({
        id: 1,
        slug: "unreaded",
        createdAt: "2026-09-01",
      });
      unreadPublic.tracking.unreadCount = 1;
      this.buildDirectMessage({
        id: 2,
        title: "Read dm",
        createdAt: "2026-09-03",
      });

      assert.deepEqual(
        this.subject.starredChannelsByPreference.map(this.channelName),
        ["unreaded"],
        "read starred channels are hidden by the unread filter"
      );
    });
  });
  module(
    "per-section filter preferences are independent",
    function (nestedHooks) {
      nestedHooks.beforeEach(function () {
        this.preferences = getOwner(this).lookup(
          "service:chat-channel-list-preferences"
        );
        this.buildPublicChannel = ({
          id,
          slug,
          createdAt,
          unreadCount = 0,
          mentionCount = 0,
          muted = false,
        }) => {
          const channel = this.fabricators.channel({
            id,
            chatable: this.fabricators.coreFabricators.category({ slug }),
          });
          channel.currentUserMembership = UserChatChannelMembership.create({
            following: true,
            muted,
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
        this.buildStarred = (args) => {
          const channel = this.buildPublicChannel(args);
          channel.currentUserMembership.starred = true;
          return channel;
        };
        this.buildDirectMessage = ({
          id,
          title,
          createdAt,
          unreadCount = 0,
          mentionCount = 0,
        }) => {
          const channel = this.fabricators.channel({
            id,
            chatable: this.fabricators.directMessage(),
            title,
          });
          channel.currentUserMembership = UserChatChannelMembership.create({
            following: true,
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

      test("changing the channels filter does not change starred or dms lists", function (assert) {
        this.buildPublicChannel({
          id: 1,
          slug: "read",
          createdAt: "2026-09-03",
        });
        this.buildPublicChannel({
          id: 2,
          slug: "unread",
          createdAt: "2026-09-03",
          unreadCount: 1,
        });
        this.buildStarred({
          id: 3,
          slug: "zulu",
          createdAt: "2026-09-04",
          unreadCount: 1,
        });
        this.buildStarred({ id: 4, slug: "alpha", createdAt: "2026-09-02" });
        this.buildDirectMessage({
          id: 5,
          title: "Zulu dm",
          createdAt: "2026-09-04",
          unreadCount: 1,
        });
        this.buildDirectMessage({
          id: 6,
          title: "Alpha dm",
          createdAt: "2026-09-02",
        });

        this.preferences.channelsFilter = CHAT_CHANNEL_LIST_FILTERS.UNREAD;

        assert.deepEqual(
          this.subject.sidebarPublicMessageChannels.map((c) => c.slug),
          ["unread"],
          "channels honor their own unread filter"
        );
        assert.deepEqual(
          this.subject.starredChannelsByPreference.map((c) => c.slug),
          ["alpha", "zulu"],
          "starred shows all channels, unaffected by the channels filter"
        );
        assert.deepEqual(
          this.subject.sidebarDirectMessageChannels.map((c) => c.title),
          ["Alpha dm", "Zulu dm"],
          "dms show all direct messages, unaffected by the channels filter"
        );
      });

      test("changing the dms filter only affects the direct messages list", function (assert) {
        this.buildPublicChannel({
          id: 1,
          slug: "read",
          createdAt: "2026-09-03",
        });
        this.buildPublicChannel({
          id: 2,
          slug: "unread",
          createdAt: "2026-09-03",
          unreadCount: 1,
        });
        this.buildDirectMessage({
          id: 5,
          title: "Read dm",
          createdAt: "2026-09-04",
        });
        this.buildDirectMessage({
          id: 6,
          title: "Unread dm",
          createdAt: "2026-09-02",
          unreadCount: 1,
        });

        this.preferences.dmsFilter = CHAT_CHANNEL_LIST_FILTERS.UNREAD;

        assert.deepEqual(
          this.subject.sidebarDirectMessageChannels.map((c) => c.title),
          ["Unread dm"],
          "dms honor their own unread filter"
        );
        assert.deepEqual(
          this.subject.sidebarPublicMessageChannels.map((c) => c.slug),
          ["read", "unread"],
          "channels show all channels, unaffected by the dms filter"
        );
      });
    }
  );
  module(
    "per-section sort preferences are independent",
    function (nestedHooks) {
      nestedHooks.beforeEach(function () {
        this.preferences = getOwner(this).lookup(
          "service:chat-channel-list-preferences"
        );
        this.buildPublicChannel = ({ id, slug, createdAt }) => {
          const channel = this.fabricators.channel({
            id,
            chatable: this.fabricators.coreFabricators.category({ slug }),
          });
          channel.currentUserMembership = UserChatChannelMembership.create({
            following: true,
          });
          channel.lastMessage = this.fabricators.message({
            id: id * 10,
            channel,
            created_at: createdAt,
          });
          this.subject.store(channel);
          return channel;
        };
        this.buildStarred = ({ id, slug, createdAt }) => {
          const channel = this.buildPublicChannel({ id, slug, createdAt });
          channel.currentUserMembership.starred = true;
          return channel;
        };
        this.buildDirectMessage = ({ id, title, createdAt }) => {
          const channel = this.fabricators.channel({
            id,
            chatable: this.fabricators.directMessage(),
            title,
          });
          channel.currentUserMembership = UserChatChannelMembership.create({
            following: true,
          });
          channel.lastMessage = this.fabricators.message({
            id: id * 10,
            channel,
            created_at: createdAt,
          });
          this.subject.store(channel);
          return channel;
        };
      });

      test("changing the channels sort does not change starred or dms sorting", function (assert) {
        this.buildPublicChannel({
          id: 1,
          slug: "older",
          createdAt: "2026-09-01",
        });
        this.buildPublicChannel({
          id: 2,
          slug: "newer",
          createdAt: "2026-09-03",
        });
        this.buildStarred({ id: 3, slug: "zulu", createdAt: "2026-09-04" });
        this.buildStarred({ id: 4, slug: "alpha", createdAt: "2026-09-02" });
        this.buildDirectMessage({
          id: 5,
          title: "Zulu dm",
          createdAt: "2026-09-04",
        });
        this.buildDirectMessage({
          id: 6,
          title: "Alpha dm",
          createdAt: "2026-09-02",
        });

        // Channels: recent activity first (starred channels stay in the list).
        this.preferences.channelsSort = CHAT_CHANNEL_LIST_SORTS.RECENT_ACTIVITY;

        assert.deepEqual(
          this.subject.publicMessageChannelsByPreference.map((c) => c.slug),
          ["zulu", "newer", "alpha", "older"],
          "channels use the channels sort"
        );
        assert.deepEqual(
          this.subject.starredChannelsByPreference.map((c) => c.slug),
          ["alpha", "zulu"],
          "starred still sorts by its own default, alphabetical"
        );
        assert.deepEqual(
          this.subject.directMessageChannelsByPreference.map((c) => c.title),
          ["Alpha dm", "Zulu dm"],
          "dms still sorts by its own default, alphabetical"
        );
      });

      test("changing the starred sort only affects the starred section", function (assert) {
        this.buildPublicChannel({
          id: 1,
          slug: "older",
          createdAt: "2026-09-01",
        });
        this.buildPublicChannel({
          id: 2,
          slug: "newer",
          createdAt: "2026-09-03",
        });
        this.buildStarred({ id: 3, slug: "zulu", createdAt: "2026-09-04" });
        this.buildStarred({ id: 4, slug: "alpha", createdAt: "2026-09-02" });

        // Starred: priority, then recency (all read → newest first).
        this.preferences.starredSort = CHAT_CHANNEL_LIST_SORTS.PRIORITY;

        assert.deepEqual(
          this.subject.starredChannelsByPreference.map((c) => c.slug),
          ["zulu", "alpha"],
          "starred honors its own priority sort"
        );
        assert.deepEqual(
          this.subject.publicMessageChannelsByPreference.map((c) => c.slug),
          ["alpha", "newer", "older", "zulu"],
          "channels keeps its own alphabetical sort, not affected by starred"
        );
      });
    }
  );
});
