import { module, test } from "qunit";
import sinon from "sinon";
import isTextInput from "discourse/float-kit/components/d-scroll/is-text-input";
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

  test("matches Silk input type classification", function (assert) {
    const hiddenInput = document.createElement("input");
    hiddenInput.type = "hidden";

    const checkbox = document.createElement("input");
    checkbox.type = "checkbox";

    assert.true(
      isTextInput(hiddenInput),
      "hidden inputs use the text-input path"
    );
    assert.false(isTextInput(checkbox), "non-text controls are excluded");
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

  test("focusing a text input does not mark a scroll before one occurs", function (assert) {
    const handler = new KeyboardFocusHandler({
      args: { safeArea: "visual-viewport" },
      getViewBoundsWithBorder: () => ({ top: 0, bottom: 100 }),
      viewElement: document.createElement("div"),
    });

    handler.handleFocus({ target: document.createElement("input") }, true);

    assert.false(
      handler.scrollTriggeredByFocus,
      "focus alone does not suppress the next user scroll"
    );
    handler.cleanup();
  });

  test("blur preserves a safe-area scroll marker until scroll end", function (assert) {
    const input = document.createElement("input");
    let handler;
    const view = {
      args: { safeArea: "visual-viewport" },
      updateSafeArea: () => {
        handler.scrollTriggeredByFocus = true;
      },
    };
    handler = new KeyboardFocusHandler(view);

    handler.handleBlur({ target: input, relatedTarget: null });

    assert.true(
      handler.scrollTriggeredByFocus,
      "the marker survives until View handles scroll end"
    );
    handler.cleanup();
  });
});
