import { module, test } from "qunit";
import sinon from "sinon";
import KeyboardFocusHandler from "discourse/float-kit/components/d-scroll/keyboard-focus-handler";

module("Unit | Lib | float-kit | keyboard-focus-handler", function (hooks) {
  let clock;

  hooks.beforeEach(function () {
    clock = sinon.useFakeTimers();
  });

  hooks.afterEach(function () {
    clock.restore();
    sinon.restore();
  });

  test("moving focus between inputs replaces the viewport listener", function (assert) {
    const addEventListener = sinon.stub(
      window.visualViewport,
      "addEventListener"
    );
    const removeEventListener = sinon.stub(
      window.visualViewport,
      "removeEventListener"
    );
    const handler = new KeyboardFocusHandler({
      args: { safeArea: "visual-viewport" },
      getViewBoundsWithBorder: () => ({ top: 0, bottom: 100 }),
      getVisualViewportBounds: () => ({ top: 0, bottom: 100 }),
      updateSafeArea: () => undefined,
      viewElement: document.createElement("div"),
    });
    const firstInput = document.createElement("input");
    const secondInput = document.createElement("input");

    handler.handleFocus({ target: firstInput }, true);
    const firstResizeHandler = handler.resizeHandler;
    handler.handleFocus({ target: secondInput }, true);

    assert.true(
      removeEventListener.calledWith("resize", firstResizeHandler),
      "the first input listener is removed"
    );
    assert.strictEqual(
      addEventListener.callCount,
      2,
      "only one listener is registered for each focused input"
    );

    handler.cleanup();
  });
});
