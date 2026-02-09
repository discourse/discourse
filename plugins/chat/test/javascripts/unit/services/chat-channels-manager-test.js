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
        unreadDmChannel.currentUserMembership =
          UserChatChannelMembership.create({
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
        unreadDmChannel.currentUserMembership =
          UserChatChannelMembership.create({
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
        unreadDmChannel.currentUserMembership =
          UserChatChannelMembership.create({
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
