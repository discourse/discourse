import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import KeyValueStore from "discourse/lib/key-value-store";
import {
  chatAlertPlayed,
  claimChatAlert,
  confirmChatAlert,
  releaseChatAlert,
  resetChatAlerts,
} from "discourse/plugins/chat/discourse/lib/chat-alert-dedup";

function alertStore() {
  return new KeyValueStore("discourse_chat_alerts_");
}

// what another tab writes when it claims an alert in the same instant
function claimFromAnotherTab(key) {
  alertStore().setObject({
    key: "handled",
    value: [{ key, at: Date.now(), tab: "other-tab" }],
  });
}

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

  test("doesn't release another tab's claim", function (assert) {
    claimFromAnotherTab(1);

    releaseChatAlert(1);

    assert.false(claimChatAlert(1), "the other tab's claim survives");
  });

  test("a played alert takes over a racing tab's claim", function (assert) {
    claimFromAnotherTab(1);

    confirmChatAlert(1);

    const [entry] = alertStore().getObject("handled");
    assert.notStrictEqual(
      entry.tab,
      "other-tab",
      "the other tab's release can no longer drop it"
    );
  });

  test("only confirmed alerts count as played", function (assert) {
    claimChatAlert(1);
    assert.false(chatAlertPlayed(1), "a claim alone isn't played");

    confirmChatAlert(1);
    assert.true(chatAlertPlayed(1), "a confirmed alert is played");
  });
});
