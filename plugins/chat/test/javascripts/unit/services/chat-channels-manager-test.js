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

    module("#sortChannelsByActivity with pinned channels", function () {
      test("prioritizes pinned channels over unpinned", function (assert) {
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
          pinned: true,
        });
        channelB.currentUserMembership = UserChatChannelMembership.create({
          following: true,
          pinned: false,
        });

        this.subject.store(channelA);
        this.subject.store(channelB);

        const result = this.subject.publicMessageChannels;

        assert.strictEqual(
          result[0].id,
          channelA.id,
          "pinned channel comes first"
        );
        assert.strictEqual(
          result[1].id,
          channelB.id,
          "unpinned channel comes second"
        );
      });

      test("sorts pinned channels alphabetically by slug", function (assert) {
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
          pinned: true,
        });
        channelA.currentUserMembership = UserChatChannelMembership.create({
          following: true,
          pinned: true,
        });
        channelB.currentUserMembership = UserChatChannelMembership.create({
          following: true,
          pinned: true,
        });

        this.subject.store(channelC);
        this.subject.store(channelA);
        this.subject.store(channelB);

        const result = this.subject.publicMessageChannels;

        assert.strictEqual(
          result[0].slug,
          "channel-a",
          "first pinned channel is A"
        );
        assert.strictEqual(
          result[1].slug,
          "channel-b",
          "second pinned channel is B"
        );
        assert.strictEqual(
          result[2].slug,
          "channel-c",
          "third pinned channel is C"
        );
      });

      test("keeps unpinned channels sorted by activity after pinned ones", function (assert) {
        const pinnedChannel = this.fabricators.channel({
          chatable: this.fabricators.coreFabricators.category({
            slug: "pinned-channel",
          }),
        });
        const unpinnedChannel = this.fabricators.channel({
          chatable: this.fabricators.coreFabricators.category({
            slug: "unpinned-channel",
          }),
        });

        pinnedChannel.currentUserMembership = UserChatChannelMembership.create({
          following: true,
          pinned: true,
        });
        unpinnedChannel.currentUserMembership =
          UserChatChannelMembership.create({
            following: true,
            pinned: false,
          });

        this.subject.store(unpinnedChannel);
        this.subject.store(pinnedChannel);

        const result = this.subject.publicMessageChannels;

        assert.strictEqual(
          result[0].id,
          pinnedChannel.id,
          "pinned channel is first"
        );
        assert.strictEqual(
          result[1].id,
          unpinnedChannel.id,
          "unpinned channel is after pinned"
        );
      });
    });

    module("#sortDirectMessageChannels with pinned channels", function () {
      test("prioritizes pinned DM channels over unpinned", function (assert) {
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
          pinned: true,
        });
        dmB.currentUserMembership = UserChatChannelMembership.create({
          following: true,
          pinned: false,
        });

        this.subject.store(dmA);
        this.subject.store(dmB);

        const result = this.subject.directMessageChannels;

        assert.strictEqual(
          result[0].id,
          dmA.id,
          "pinned DM channel comes first"
        );
        assert.strictEqual(
          result[1].id,
          dmB.id,
          "unpinned DM channel comes second"
        );
      });

      test("sorts pinned DM channels alphabetically by title", function (assert) {
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
          pinned: true,
        });
        dmAlice.currentUserMembership = UserChatChannelMembership.create({
          following: true,
          pinned: true,
        });
        dmBob.currentUserMembership = UserChatChannelMembership.create({
          following: true,
          pinned: true,
        });

        this.subject.store(dmCharlie);
        this.subject.store(dmAlice);
        this.subject.store(dmBob);

        const result = this.subject.directMessageChannels;

        assert.strictEqual(
          result[0].title,
          "Alice",
          "first pinned DM is Alice"
        );
        assert.strictEqual(result[1].title, "Bob", "second pinned DM is Bob");
        assert.strictEqual(
          result[2].title,
          "Charlie",
          "third pinned DM is Charlie"
        );
      });

      test("keeps unpinned DM channels sorted by activity after pinned ones", function (assert) {
        const pinnedDM = this.fabricators.channel({
          chatable: this.fabricators.directMessage(),
          title: "Pinned User",
        });
        const unpinnedDM = this.fabricators.channel({
          chatable: this.fabricators.directMessage(),
          title: "Unpinned User",
        });

        pinnedDM.currentUserMembership = UserChatChannelMembership.create({
          following: true,
          pinned: true,
        });
        unpinnedDM.currentUserMembership = UserChatChannelMembership.create({
          following: true,
          pinned: false,
        });

        this.subject.store(unpinnedDM);
        this.subject.store(pinnedDM);

        const result = this.subject.directMessageChannels;

        assert.strictEqual(
          result[0].id,
          pinnedDM.id,
          "pinned DM channel is first"
        );
        assert.strictEqual(
          result[1].id,
          unpinnedDM.id,
          "unpinned DM channel is after pinned"
        );
      });
    });
  }
);
