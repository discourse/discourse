import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import Site from "discourse/models/site";
import {
  addChatDrawerStateCallback,
  resetChatDrawerStateCallbacks,
} from "discourse/plugins/chat/discourse/services/chat-state-manager";

module(
  "Discourse Chat | Unit | Service | chat-state-manager",
  function (hooks) {
    setupTest(hooks);

    hooks.beforeEach(function () {
      this.subject = getOwner(this).lookup("service:chat-state-manager");
    });

    hooks.afterEach(function () {
      this.subject.reset();
    });

    test("isFullPagePreferred", function (assert) {
      assert.false(this.subject.isFullPagePreferred);

      this.subject.prefersFullPage();

      assert.ok(this.subject.isFullPagePreferred);

      this.subject.prefersDrawer();

      assert.false(this.subject.isFullPagePreferred);

      this.subject.prefersDrawer();
      Site.currentProp("mobileView", true);

      assert.ok(this.subject.isFullPagePreferred);
    });

    test("isDrawerPreferred", function (assert) {
      assert.ok(this.subject.isDrawerPreferred);

      this.subject.prefersFullPage();

      assert.false(this.subject.isDrawerPreferred);

      this.subject.prefersDrawer();

      assert.ok(this.subject.isDrawerPreferred);
    });

    test("lastKnownChatURL", function (assert) {
      assert.strictEqual(this.subject.lastKnownChatURL, "/chat");

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

    test("isFullPageActive", function (assert) {
      sinon.stub(this.subject.router, "currentRouteName").value("foo");
      assert.false(this.subject.isFullPageActive);

      sinon.stub(this.subject.router, "currentRouteName").value("chat");
      assert.ok(this.subject.isFullPageActive);
    });

    test("didCollapseDrawer", function (assert) {
      this.subject.didCollapseDrawer();

      assert.strictEqual(this.subject.isDrawerExpanded, false);
      assert.strictEqual(this.subject.isDrawerActive, true);
    });

    test("didExpandDrawer", function (assert) {
      const stub = sinon.stub(
        this.owner.lookup("service:chat"),
        "updatePresence"
      );

      this.subject.didExpandDrawer();

      assert.strictEqual(this.subject.isDrawerExpanded, true);
      assert.strictEqual(this.subject.isDrawerActive, true);
      sinon.assert.calledOnce(stub);
    });

    test("didCloseDrawer", function (assert) {
      const stub = sinon.stub(
        this.owner.lookup("service:chat"),
        "updatePresence"
      );

      this.subject.didCloseDrawer();

      assert.strictEqual(this.subject.isDrawerExpanded, false);
      assert.strictEqual(this.subject.isDrawerActive, false);
      sinon.assert.calledOnce(stub);
    });

    test("didOpenDrawer", function (assert) {
      const stub = sinon.stub(
        this.owner.lookup("service:chat"),
        "updatePresence"
      );

      this.subject.didOpenDrawer();

      assert.strictEqual(this.subject.isDrawerExpanded, true);
      assert.strictEqual(this.subject.isDrawerActive, true);
      assert.strictEqual(this.subject.lastKnownChatURL, "/chat");

      this.subject.didOpenDrawer("/foo");

      assert.strictEqual(this.subject.lastKnownChatURL, "/foo");
      sinon.assert.calledTwice(stub);
    });

    test("callbacks", function (assert) {
      this.state = null;
      addChatDrawerStateCallback((state) => {
        this.state = state;
      });

      this.subject.didOpenDrawer();

      assert.strictEqual(this.state.isDrawerActive, true);
      assert.strictEqual(this.state.isDrawerExpanded, true);

      this.subject.didCloseDrawer();

      assert.strictEqual(this.state.isDrawerActive, false);
      assert.strictEqual(this.state.isDrawerExpanded, false);

      resetChatDrawerStateCallbacks();
    });
  }
);
