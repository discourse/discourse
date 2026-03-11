import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Discourse Chat | Unit | Models | chat-channel", function (hooks) {
  setupTest(hooks);

  module("unreadThreadsCount", function () {
    test("returns 0 when threading is disabled", function (assert) {
      const channel = new ChatFabricators(getOwner(this)).channel();
      channel.threadingEnabled = false;
      channel.threadsManager.markThreadUnread(1, new Date());

      assert.strictEqual(channel.unreadThreadsCount, 0);
    });

    test("returns count when threading is enabled", function (assert) {
      const channel = new ChatFabricators(getOwner(this)).channel();
      channel.threadingEnabled = true;
      channel.threadsManager.markThreadUnread(1, new Date());
      channel.threadsManager.markThreadUnread(2, new Date());

      assert.strictEqual(channel.unreadThreadsCount, 2);
    });
  });

  module("unreadThreadsCountSinceLastViewed", function () {
    test("returns 0 when threading is disabled", function (assert) {
      const channel = new ChatFabricators(getOwner(this)).channel();
      channel.threadingEnabled = false;
      channel.currentUserMembership.lastViewedAt = new Date(2000, 0, 1);
      channel.threadsManager.markThreadUnread(1, new Date());

      assert.strictEqual(channel.unreadThreadsCountSinceLastViewed, 0);
    });

    test("returns count of threads since last viewed when threading is enabled", function (assert) {
      const channel = new ChatFabricators(getOwner(this)).channel();
      channel.threadingEnabled = true;

      const lastViewed = new Date(2024, 0, 15);
      channel.currentUserMembership.lastViewedAt = lastViewed;

      channel.threadsManager.markThreadUnread(1, new Date(2024, 0, 10));
      channel.threadsManager.markThreadUnread(2, new Date(2024, 0, 20));
      channel.threadsManager.markThreadUnread(3, new Date(2024, 0, 25));

      assert.strictEqual(channel.unreadThreadsCountSinceLastViewed, 2);
    });
  });

  module("watchedThreadsUnreadCount", function () {
    test("returns 0 when threading is disabled", function (assert) {
      const fabricators = new ChatFabricators(getOwner(this));
      const channel = fabricators.channel();
      channel.threadingEnabled = false;

      const thread = fabricators.thread({ channel });
      channel.threadsManager.add(channel, thread);
      thread.tracking.watchedThreadsUnreadCount = 3;

      assert.strictEqual(channel.watchedThreadsUnreadCount, 0);
    });

    test("returns sum of watched threads unread counts when threading is enabled", function (assert) {
      const fabricators = new ChatFabricators(getOwner(this));
      const channel = fabricators.channel();
      channel.threadingEnabled = true;

      const thread1 = fabricators.thread({ channel });
      const thread2 = fabricators.thread({ channel });
      channel.threadsManager.add(channel, thread1);
      channel.threadsManager.add(channel, thread2);
      thread1.tracking.watchedThreadsUnreadCount = 3;
      thread2.tracking.watchedThreadsUnreadCount = 5;

      assert.strictEqual(channel.watchedThreadsUnreadCount, 8);
    });
  });
});
