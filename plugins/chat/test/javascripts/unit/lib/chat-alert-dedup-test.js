import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import {
  claimChatAlert,
  releaseChatAlert,
  resetChatAlerts,
} from "discourse/plugins/chat/discourse/lib/chat-alert-dedup";

module("Unit | chat-alert-dedup", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    resetChatAlerts();
  });

  hooks.afterEach(function () {
    resetChatAlerts();
  });

  test("claims an alert only once", function (assert) {
    assert.true(claimChatAlert(1), "first claim succeeds");
    assert.false(claimChatAlert(1), "second claim is rejected");
    assert.true(claimChatAlert(2), "a different alert can be claimed");
  });

  test("always allows alerts without a key", function (assert) {
    assert.true(claimChatAlert(undefined));
    assert.true(claimChatAlert(undefined));
  });

  test("released alerts can be claimed again", function (assert) {
    assert.true(claimChatAlert(1), "first claim succeeds");

    releaseChatAlert(1);

    assert.true(claimChatAlert(1), "claim succeeds again after release");
    assert.false(claimChatAlert(1), "and is exclusive again");
  });

  test("expires old claims", function (assert) {
    const clock = sinon.useFakeTimers({
      now: Date.now(),
      toFake: ["Date"],
    });

    try {
      assert.true(claimChatAlert(1), "first claim succeeds");

      clock.tick(6 * 60 * 1000);

      assert.true(claimChatAlert(1), "claim succeeds again after expiry");
    } finally {
      clock.restore();
    }
  });
});
