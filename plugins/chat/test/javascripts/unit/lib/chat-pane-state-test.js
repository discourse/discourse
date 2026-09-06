import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import {
  clearPresenceCallbacks,
  setTestPresence,
} from "discourse/lib/user-presence";
import ChatPaneState from "discourse/plugins/chat/discourse/lib/chat-pane-state";

module("Unit | Lib | chat-pane-state", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    setTestPresence(true);
    sinon.stub(document, "hasFocus").returns(false);
    sinon.stub(document, "visibilityState").value("visible");
  });

  hooks.afterEach(function () {
    setTestPresence(true);
    clearPresenceCallbacks();
    sinon.restore();
  });

  test("live-follow can continue while unfocused without marking read", function (assert) {
    const paneState = new ChatPaneState(getOwner(this), {
      contextKey: "channel:1",
    });
    let addedMessageCount = 0;
    const addMessage = () => addedMessageCount++;

    for (let i = 0; i < 700; i++) {
      paneState.handleIncomingMessage({
        shouldAutoScroll: true,
        addMessage,
      });
    }

    assert.strictEqual(addedMessageCount, 700, "live-follow can continue");
    assert.false(paneState.shouldMarkRead(), "suppresses read acknowledgement");

    paneState.teardown();
  });

  test("active-reader transition runs return callback when focus returns", function (assert) {
    const onUserPresent = sinon.spy();
    const paneState = new ChatPaneState(getOwner(this), {
      contextKey: "channel:1",
      onUserPresent,
    });

    document.hasFocus.returns(true);
    paneState.onBrowserAttentionChange();

    assert.true(onUserPresent.calledOnce, "notifies the pane to mark read");
    assert.true(paneState.shouldMarkRead(), "allows read acknowledgements");

    paneState.teardown();
  });

  test("own messages can live-follow while unfocused", function (assert) {
    const paneState = new ChatPaneState(getOwner(this), {
      contextKey: "channel:1",
    });

    assert.true(
      paneState.shouldAutoScrollIncomingMessage({
        isAtLiveEdge: true,
        isOwnMessage: true,
      }),
      "own messages keep following the live edge"
    );

    paneState.teardown();
  });

  test("active readers can mark visible messages read away from the live edge", function (assert) {
    document.hasFocus.returns(true);

    const paneState = new ChatPaneState(getOwner(this), {
      contextKey: "channel:1",
    });

    paneState.updateLiveEdgeFromDistance(250);

    assert.true(
      paneState.shouldMarkRead(),
      "read acknowledgement follows attention, not only the live edge"
    );

    paneState.teardown();
  });

  test("uses a small live-edge threshold", function (assert) {
    const paneState = new ChatPaneState(getOwner(this), {
      contextKey: "channel:1",
    });

    paneState.updateLiveEdgeFromDistance(11);
    assert.false(paneState.isAtLiveEdge, "11px from the bottom is not live");

    paneState.updateLiveEdgeFromDistance(10);
    assert.true(paneState.isAtLiveEdge, "10px from the bottom is live");

    paneState.teardown();
  });

  test("captures live-edge state when the reader becomes passive", function (assert) {
    document.hasFocus.returns(true);

    const paneState = new ChatPaneState(getOwner(this), {
      contextKey: "channel:1",
    });

    paneState.updateLiveEdgeFromDistance(250);
    paneState.updateLiveEdgeFromDistance(0);
    document.hasFocus.returns(false);
    paneState.onBrowserAttentionChange();

    assert.true(
      paneState.shouldAutoScrollIncomingMessage({ isAtLiveEdge: true }),
      "continues live-follow after focus leaves while at the live edge"
    );

    paneState.teardown();
  });
});
