import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { AUTO_GROUPS } from "discourse/lib/constants";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Unit | Service | chat | anonymous", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    const owner = getOwner(this);

    this.chat = owner.lookup("service:chat");
    this.chatSubscriptionsManager = owner.lookup(
      "service:chat-subscriptions-manager"
    );
    this.siteSettings = owner.lookup("service:site-settings");
    this.fabricators = new ChatFabricators(owner);

    this.siteSettings.chat_allowed_groups =
      AUTO_GROUPS.anonymous_users.id.toString();

    sinon.stub(this.chatSubscriptionsManager, "startChannelsSubscriptions");
    sinon.stub(this.chatSubscriptionsManager, "startChannelSubscription");
  });

  hooks.afterEach(function () {
    sinon.restore();
  });

  test("setupWithPreloadedChannels skips realtime subscriptions by default", function (assert) {
    const channel = this.fabricators.channel({
      meta: {
        message_bus_last_ids: {
          channel_message_bus_last_id: 1,
        },
      },
    });

    this.chat.setupWithPreloadedChannels({
      public_channels: [channel],
      direct_message_channels: [],
      has_threads: false,
      meta: {
        message_bus_last_ids: {
          channel_metadata: 1,
          channel_edits: 1,
          channel_status: 1,
        },
      },
      tracking: {
        channel_tracking: {},
        thread_tracking: {},
      },
    });

    assert.false(
      this.chatSubscriptionsManager.startChannelsSubscriptions.called,
      "global channel subscriptions are skipped"
    );
    assert.false(
      this.chatSubscriptionsManager.startChannelSubscription.called,
      "per-channel subscriptions are skipped"
    );
  });
});
