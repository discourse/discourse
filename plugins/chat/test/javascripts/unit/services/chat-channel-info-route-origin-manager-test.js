import { module, test } from "qunit";
import { getOwner } from "@ember/application";
import { ORIGINS } from "discourse/plugins/chat/discourse/services/chat-channel-info-route-origin-manager";
import { setupTest } from "ember-qunit";

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
      this.manager.origin = ORIGINS.channnel;
      assert.strictEqual(this.manager.origin, ORIGINS.channnel);
    });

    test(".isBrowse", function (assert) {
      this.manager.origin = ORIGINS.browse;
      assert.strictEqual(this.manager.isBrowse, true);

      this.manager.origin = null;
      assert.strictEqual(this.manager.isBrowse, false);

      this.manager.origin = ORIGINS.channel;
      assert.strictEqual(this.manager.isBrowse, false);
    });

    test(".isChannel", function (assert) {
      this.manager.origin = ORIGINS.channnel;
      assert.strictEqual(this.manager.isChannel, true);

      this.manager.origin = ORIGINS.browse;
      assert.strictEqual(this.manager.isChannel, false);

      this.manager.origin = null;
      assert.strictEqual(this.manager.isChannel, true);
    });
  }
);
