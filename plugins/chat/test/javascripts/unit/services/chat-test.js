import { settled } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Unit | Service | chat", function (needs) {
  needs.user();

  needs.hooks.beforeEach(function () {
    Object.defineProperty(this, "currentUser", {
      get: () => this.container.lookup("service:current-user"),
    });
    Object.defineProperty(this, "chat", {
      get: () => this.container.lookup("service:chat"),
    });
    this.chatTrackingStateManager = this.container.lookup(
      "service:chat-tracking-state-manager"
    );
    this.chatPanePendingManager = this.container.lookup(
      "service:chat-pane-pending-manager"
    );
    sinon
      .stub(this.chatTrackingStateManager, "allChannelUrgentCount")
      .returns(5);
    sinon
      .stub(this.chatPanePendingManager, "totalPendingMessageCount")
      .get(() => 10);
  });

  test("getDocumentTitleCount returns urgent count when title_count_mode is 'notifications'", function (assert) {
    this.currentUser.user_option.title_count_mode = "notifications";

    const count = this.chat.getDocumentTitleCount();

    assert.strictEqual(
      count,
      5,
      "returns only urgent count (mentions, DMs, watched threads)"
    );
  });

  test("getDocumentTitleCount returns pending count when title_count_mode is 'contextual'", function (assert) {
    this.currentUser.user_option.title_count_mode = "contextual";

    const count = this.chat.getDocumentTitleCount();

    assert.strictEqual(count, 10, "returns pending count");
  });

  test("getDocumentTitleCount returns pending count when user_option is null", function (assert) {
    this.currentUser.user_option = null;

    const count = this.chat.getDocumentTitleCount();

    assert.strictEqual(count, 10, "returns pending count");
  });

  test("updatePresence leaves chat presence while chat isn't open", async function (assert) {
    const { enter, leave } = (this.chat.presenceChannel = {
      enter: sinon.stub(),
      leave: sinon.stub(),
    });

    this.chat.updatePresence();
    await settled();

    assert.false(enter.called, "doesn't enter");
    assert.true(leave.calledOnce, "leaves");
  });

  test("updatePresence counts what chat-presence-active says is active", async function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer("chat-presence-active", () => true);
    });
    const { enter, leave } = (this.chat.presenceChannel = {
      enter: sinon.stub(),
      leave: sinon.stub(),
    });

    this.chat.updatePresence();
    await settled();

    assert.true(enter.calledOnce, "enters");
    assert.false(leave.called, "doesn't leave");
  });

  test("updatePresence still respects hidden presence", async function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer("chat-presence-active", () => true);
    });
    this.currentUser.user_option.hide_presence = true;
    const { enter } = (this.chat.presenceChannel = {
      enter: sinon.stub(),
      leave: sinon.stub(),
    });

    this.chat.updatePresence();
    await settled();

    assert.false(enter.called, "doesn't enter");
  });
});
