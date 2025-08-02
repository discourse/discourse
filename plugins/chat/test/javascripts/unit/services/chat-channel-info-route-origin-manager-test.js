import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { ORIGINS } from "discourse/plugins/chat/discourse/services/chat-channel-info-route-origin-manager";

module(
  "Discourse Chat | Unit | Service | chat-channel-info-route-origin-manager",
  function (hooks) {
    setupTest(hooks);

    hooks.beforeEach(function () {
      this.manager = getOwner(this).lookup(
        "service:chat-channel-info-route-origin-manager"
      );
    });

    hooks.afterEach(function () {
      this.manager.origin = null;
    });

    test(".origin", function (assert) {
      this.manager.origin = ORIGINS.channel;
      assert.strictEqual(this.manager.origin, ORIGINS.channel);
    });

    test(".isBrowse", function (assert) {
      this.manager.origin = ORIGINS.browse;
      assert.true(this.manager.isBrowse);

      this.manager.origin = null;
      assert.false(this.manager.isBrowse);

      this.manager.origin = ORIGINS.channel;
      assert.false(this.manager.isBrowse);
    });

    test(".isChannel", function (assert) {
      this.manager.origin = ORIGINS.channel;
      assert.true(this.manager.isChannel);

      this.manager.origin = ORIGINS.browse;
      assert.false(this.manager.isChannel);

      this.manager.origin = null;
      assert.true(this.manager.isChannel);
    });
  }
);
