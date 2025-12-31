import { test } from "qunit";
import sinon from "sinon";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Discourse Chat | Unit | Service | chat", function (needs) {
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
      .get(() => 5);
    sinon
      .stub(this.chatPanePendingManager, "totalPendingMessageCount")
      .get(() => 10);
  });

  test("getDocumentTitleCount returns urget count when title_count_mode is 'notifications'", function (assert) {
    this.currentUser.user_option.title_count_mode = "notifications";

    const count = this.chat.getDocumentTitleCount();

    assert.strictEqual(
      count,
      5,
      "returns only urgent count (mentions, DMs, watched threads)"
    );
  });

  test("getDocumentTitleCount returns urgent + pending count when title_count_mode is 'contextual'", function (assert) {
    this.currentUser.user_option.title_count_mode = "contextual";

    const count = this.chat.getDocumentTitleCount();

    assert.strictEqual(
      count,
      15,
      "returns urgent + pending count (all chat activity)"
    );
  });

  test("getDocumentTitleCount returns urgent + pending count when user_option is null", function (assert) {
    this.currentUser.user_option = null;

    const count = this.chat.getDocumentTitleCount();

    assert.strictEqual(
      count,
      15,
      "returns full count when user_option is not set"
    );
  });
});
