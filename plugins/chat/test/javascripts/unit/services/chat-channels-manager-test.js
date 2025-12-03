import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import UserChatChannelMembership from "discourse/plugins/chat/discourse/models/user-chat-channel-membership";

module(
  "Discourse Chat | Unit | Service | chat-channels-manager",
  function (hooks) {
    setupTest(hooks);

    hooks.beforeEach(function () {
      this.subject = getOwner(this).lookup("service:chat-channels-manager");
      this.fabricators = new ChatFabricators(getOwner(this));
      this.siteSettings = getOwner(this).lookup("service:site-settings");
      this.siteSettings.star_chat_channels = true;
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

        starredChannel.currentUserMembership = UserChatChannelMembership.create(
          {
            following: true,
            starred: true,
          }
        );
        unstarredChannel.currentUserMembership =
          UserChatChannelMembership.create({
            following: true,
            starred: false,
          });

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
      test("returns all channels sorted by activity when starring is disabled", function (assert) {
        this.siteSettings.star_chat_channels = false;

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

        const result = this.subject.unstarredPublicMessageChannelsByActivity;

        assert.strictEqual(result.length, 2, "returns all channels");
      });

      test("excludes starred channels when starring is enabled", function (assert) {
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

        starredChannel.currentUserMembership = UserChatChannelMembership.create(
          {
            following: true,
            starred: true,
          }
        );
        unstarredChannel.currentUserMembership =
          UserChatChannelMembership.create({
            following: true,
            starred: false,
          });

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
        channelNoUnread.currentUserMembership =
          UserChatChannelMembership.create({
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
      test("returns empty array when starring is disabled", function (assert) {
        this.siteSettings.star_chat_channels = false;

        const channel = this.fabricators.channel({
          chatable: this.fabricators.coreFabricators.category({
            slug: "test",
          }),
        });
        channel.currentUserMembership = UserChatChannelMembership.create({
          following: true,
          starred: true,
        });

        this.subject.store(channel);

        assert.strictEqual(
          this.subject.starredChannelsByActivity.length,
          0,
          "returns empty array"
        );
      });

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
        channelNoUnread.currentUserMembership =
          UserChatChannelMembership.create({
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

        assert.strictEqual(
          result[0].title,
          "Alice",
          "first starred DM is Alice"
        );
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
  }
);
