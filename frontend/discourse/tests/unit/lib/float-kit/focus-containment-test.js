import { module, test } from "qunit";
import sinon from "sinon";
import setupFocusContainment from "discourse/float-kit/components/d-sheet/focus-containment";

module("Unit | Lib | float-kit | focus-containment", function (hooks) {
  hooks.afterEach(() => sinon.restore());

  test("cleanup cancels a deferred focus wrap", function (assert) {
    const frames = new Map();
    let nextFrame = 1;
    sinon.stub(window, "requestAnimationFrame").callsFake((callback) => {
      const frame = nextFrame++;
      frames.set(frame, callback);
      return frame;
    });
    sinon.stub(window, "cancelAnimationFrame").callsFake((frame) => {
      frames.delete(frame);
    });

    const root = document.createElement("div");
    const button = document.createElement("button");
    button.style.width = "1px";
    button.style.height = "1px";
    root.appendChild(button);
    document.querySelector("#qunit-fixture").appendChild(root);

    const { cleanup, guardElements } = setupFocusContainment({
      getElementFocusedLast: () => null,
      rootElements: [root],
      setElementFocusedLast() {},
      viewElement: root,
    });
    const focus = sinon.spy(button, "focus");

    button.dispatchEvent(
      new FocusEvent("focusout", {
        bubbles: true,
        relatedTarget: guardElements[1],
      })
    );

    assert.strictEqual(frames.size, 1, "focus wrapping waits for one frame");

    cleanup();

    assert.strictEqual(frames.size, 0, "cleanup cancels the pending frame");
    assert.false(focus.called, "cleaned-up containment cannot reclaim focus");
  });

  test("ignores the temporary DScroll focus clone", function (assert) {
    const root = document.createElement("div");
    const button = document.createElement("button");
    const clone = document.createElement("input");
    const setElementFocusedLast = sinon.spy();

    root.append(button);
    clone.setAttribute("data-d-scroll-clone", "true");
    document.querySelector("#qunit-fixture").append(root, clone);

    const { cleanup } = setupFocusContainment({
      getElementFocusedLast: () => null,
      rootElements: [root],
      setElementFocusedLast,
      viewElement: root,
    });
    const focus = sinon.spy(button, "focus");

    clone.dispatchEvent(new FocusEvent("focusin", { bubbles: true }));

    assert.false(
      setElementFocusedLast.called,
      "the clone is not recorded as layer focus"
    );
    assert.false(focus.called, "the clone does not trigger focus recovery");

    cleanup();
  });
});
