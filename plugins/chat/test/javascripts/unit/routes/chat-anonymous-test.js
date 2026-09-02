import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { MAIN_PANEL } from "discourse/lib/sidebar/panels";
import { CHAT_PANEL } from "discourse/plugins/chat/discourse/lib/init-sidebar-state";

module("Unit | Routes | chat | anonymous", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.testOwner = getOwner(this);
  });

  hooks.afterEach(function () {
    sinon.restore();
  });

  test("follows the never site setting", function (assert) {
    const route = this.testOwner.lookup("route:chat");
    const sidebarState = this.testOwner.lookup("service:sidebar-state");
    route.siteSettings.chat_separate_sidebar_mode = "never";
    sinon.stub(route.chatStateManager, "storeAppURL");
    sinon.stub(route.chat, "updatePresence");

    route.activate();

    assert.true(sidebarState.combinedMode, "uses combined sidebar mode");
    assert.strictEqual(
      sidebarState.currentPanelKey,
      MAIN_PANEL,
      "keeps the main panel selected"
    );
    assert.false(
      sidebarState.displaySwitchPanelButtons,
      "hides the panel switch buttons"
    );
  });

  test("follows the always site setting", function (assert) {
    const route = this.testOwner.lookup("route:chat");
    const sidebarState = this.testOwner.lookup("service:sidebar-state");
    route.siteSettings.chat_separate_sidebar_mode = "always";
    sinon.stub(route.chatStateManager, "storeAppURL");
    sinon.stub(route.chat, "updatePresence");

    route.activate();

    assert.false(sidebarState.combinedMode, "uses separated sidebar mode");
    assert.strictEqual(
      sidebarState.currentPanelKey,
      CHAT_PANEL,
      "selects the chat panel"
    );
    assert.true(
      sidebarState.displaySwitchPanelButtons,
      "shows the panel switch buttons"
    );
  });

  test("direct messages redirects anonymous users to public channels", function (assert) {
    const route = this.testOwner.lookup("route:chat.direct-messages");
    sinon.stub(route.router, "replaceWith");

    route.beforeModel();

    assert.true(route.router.replaceWith.calledWith("chat.channels"));
  });

  test("new message redirects anonymous users to public channels", async function (assert) {
    const route = this.testOwner.lookup("route:chat.new-message");
    const transition = { abort: sinon.stub() };
    sinon.stub(route.router, "transitionTo");

    await route.beforeModel(transition);

    assert.true(transition.abort.calledOnce);
    assert.true(route.router.transitionTo.calledWith("chat.channels"));
  });

  test("search redirects anonymous users to public channels", function (assert) {
    const route = this.testOwner.lookup("route:chat.search");
    sinon.stub(route.router, "transitionTo");

    route.redirect();

    assert.true(route.router.transitionTo.calledWith("chat.channels"));
  });

  test("starred channels redirects anonymous users to public channels", async function (assert) {
    const route = this.testOwner.lookup("route:chat.starred-channels");
    sinon.stub(route.router, "replaceWith");

    await route.beforeModel();

    assert.true(route.router.replaceWith.calledWith("chat.channels"));
  });

  test("threads redirects anonymous users to public channels", function (assert) {
    const route = this.testOwner.lookup("route:chat.threads");
    sinon.stub(route.router, "replaceWith");

    route.beforeModel();

    assert.true(route.router.replaceWith.calledWith("chat.channels"));
  });
});
