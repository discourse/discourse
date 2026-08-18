import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Unit | Service | embeddable-chat", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    const owner = getOwner(this);

    owner.register(
      "controller:topic",
      { model: { chat_channel_id: 9 } },
      { instantiate: false }
    );

    this.subject = owner.lookup("service:embeddable-chat");
    this.subject.set("siteSettings", { chat_enabled: true });
    this.subject.set("currentUser", {});
    this.subject.set("capabilities", { viewport: { lg: true } });
    this.subject.set("router", { currentRouteName: "topic" });
    this.subject.set("chat", { userCanChat: true });
  });

  test("renders on the livestream topic route", function (assert) {
    this.subject.set("router", { currentRouteName: "topic" });
    assert.true(this.subject.canRenderChatChannel(false));
  });

  test("renders on the zoom route", function (assert) {
    this.subject.set("router", { currentRouteName: "topic-zoom" });
    assert.true(this.subject.canRenderChatChannel(false));
  });

  test("does not render on unrelated routes even with a leftover channel", function (assert) {
    this.subject.set("router", {
      currentRouteName: "admin.customize.themes",
    });
    assert.false(this.subject.canRenderChatChannel(false));
  });

  test("does not render when the topic has no chat channel", function (assert) {
    getOwner(this).lookup("controller:topic").model = {};
    this.subject.set("router", { currentRouteName: "topic" });
    assert.false(this.subject.canRenderChatChannel(false));
  });

  test("requires the correct viewport", function (assert) {
    this.subject.set("router", { currentRouteName: "topic" });
    // Desktop viewport expected but mobile requested, and vice versa.
    assert.false(this.subject.canRenderChatChannel(true));

    this.subject.set("capabilities", { viewport: { lg: false } });
    assert.true(this.subject.canRenderChatChannel(true));
  });
});
