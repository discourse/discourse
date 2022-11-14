import { module, test } from "qunit";
import { setupTest } from "ember-qunit";
import Site from "discourse/models/site";
import sinon from "sinon";

module(
  "Discourse Chat | Unit | Service | chat-state-manager",
  function (hooks) {
    setupTest(hooks);

    hooks.beforeEach(function () {
      this.subject = this.owner.lookup("service:chat-state-manager");
    });

    hooks.afterEach(function () {
      this.subject.reset();
    });

    test("isFullPagePreferred", function (assert) {
      assert.notOk(this.subject.isFullPagePreferred);

      this.subject.prefersFullPage();

      assert.ok(this.subject.isFullPagePreferred);

      this.subject.prefersDrawer();

      assert.notOk(this.subject.isFullPagePreferred);

      this.subject.prefersDrawer();
      Site.currentProp("mobileView", true);

      assert.ok(this.subject.isFullPagePreferred);
    });

    test("isDrawerPreferred", function (assert) {
      assert.ok(this.subject.isDrawerPreferred);

      this.subject.prefersFullPage();

      assert.notOk(this.subject.isDrawerPreferred);

      this.subject.prefersDrawer();

      assert.ok(this.subject.isDrawerPreferred);
    });

    test("lastKnownChatURL", function (assert) {
      assert.strictEqual(this.subject.lastKnownChatURL, "/chat");

      sinon.stub(this.subject.router, "currentURL").value("/foo");
      this.subject.storeChatURL();

      assert.strictEqual(this.subject.lastKnownChatURL, "/foo");

      this.subject.storeChatURL("/bar");

      assert.strictEqual(this.subject.lastKnownChatURL, "/bar");
    });

    test("lastKnownAppURL", function (assert) {
      assert.strictEqual(this.subject.lastKnownAppURL, "/latest");

      sinon.stub(this.subject.router, "currentURL").value("/foo");
      this.subject.storeAppURL();

      assert.strictEqual(this.subject.lastKnownAppURL, "/foo");

      this.subject.storeAppURL("/bar");

      assert.strictEqual(this.subject.lastKnownAppURL, "/bar");
    });

    test("isFullPage", function (assert) {
      sinon.stub(this.subject.router, "currentRouteName").value("foo");
      assert.notOk(this.subject.isFullPage);

      sinon.stub(this.subject.router, "currentRouteName").value("chat");
      assert.ok(this.subject.isFullPage);
    });
  }
);
