import { module, test } from "qunit";
import ChatDrawer from "discourse/plugins/chat/discourse/components/chat-drawer";

module("Unit | Component | ChatDrawer", function () {
  test("resize start tolerates an active drawer whose container is absent", function (assert) {
    let didThrow = false;

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
