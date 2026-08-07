import { module, test } from "qunit";
import ChatDrawer from "discourse/plugins/chat/discourse/components/chat-drawer";

const CONTAINER = ".chat-drawer-outlet-container";

module("Unit | Component | ChatDrawer", function () {
  test("resize start tolerates an active drawer whose container is absent", function (assert) {
    let didThrow = false;

    // The premise of the test: with a container present these would not reach
    // the guard at all, and would pass without exercising anything.
    assert.strictEqual(
      document.querySelector(CONTAINER),
      null,
      "no drawer container is rendered"
    );

    try {
      ChatDrawer.prototype._startDynamicCheckSize.call({
        chatStateManager: { isDrawerActive: true },
      });
    } catch {
      didThrow = true;
    }

    assert.false(
      didThrow,
      "composer resize start tolerates a missing chat drawer container"
    );
  });

  test("resize end tolerates an active drawer whose container is absent", function (assert) {
    let didThrow = false;

    assert.strictEqual(
      document.querySelector(CONTAINER),
      null,
      "no drawer container is rendered"
    );

    try {
      ChatDrawer.prototype._clearDynamicCheckSize.call({
        chatStateManager: { isDrawerActive: true },
        _checkSize() {},
      });
    } catch {
      didThrow = true;
    }

    assert.false(
      didThrow,
      "composer resize end tolerates a missing chat drawer container"
    );
  });
});
