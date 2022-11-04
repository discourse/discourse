import { module, test } from "qunit";
import { getOwner } from "discourse-common/lib/get-owner";
import Site from "discourse/models/site";

module(
  "Discourse Chat | Unit | Service | chat-preferred-mode",
  function (hooks) {
    hooks.beforeEach(function () {
      Site.currentProp("mobileView", false);

      this.chatPreferredMode = getOwner(this).lookup(
        "service:chat-preferred-mode"
      );
    });

    test("defaults", function (assert) {
      assert.strictEqual(this.chatPreferredMode.isDrawer, true);
      assert.strictEqual(this.chatPreferredMode.isFullPage, false);

      Site.currentProp("mobileView", true);

      assert.strictEqual(this.chatPreferredMode.isDrawer, false);
      assert.strictEqual(this.chatPreferredMode.isFullPage, true);
    });

    test("setFullPage", function (assert) {
      this.chatPreferredMode.setFullPage();
      assert.strictEqual(this.chatPreferredMode.isFullPage, true);
      assert.strictEqual(this.chatPreferredMode.isDrawer, false);
    });

    test("setDrawer", function (assert) {
      this.chatPreferredMode.setDrawer();
      assert.strictEqual(this.chatPreferredMode.isFullPage, false);
      assert.strictEqual(this.chatPreferredMode.isDrawer, true);
    });
  }
);
