import { module, test } from "qunit";
import ObserverManager from "discourse/float-kit/components/d-sheet/observer-manager";

module("Unit | FloatKit | d-sheet observer manager", function (hooks) {
  let originalResizeObserver;

  hooks.beforeEach(function () {
    originalResizeObserver = window.ResizeObserver;
  });

  hooks.afterEach(function () {
    window.ResizeObserver = originalResizeObserver;
  });

  test("detached resize targets are unobserved", function (assert) {
    const observed = [];
    const unobserved = [];

    window.ResizeObserver = class {
      disconnect() {}

      observe(element) {
        observed.push(element);
      }

      unobserve(element) {
        unobserved.push(element);
      }
    };

    const view = document.createElement("div");
    const content = document.createElement("div");
    const manager = new ObserverManager({ content, view });

    manager.setupResizeObserver(() => {});
    manager.unobserveResizeTarget(view);
    manager.unobserveResizeTarget(content);

    assert.deepEqual(observed, [view, content], "both targets are observed");
    assert.deepEqual(
      unobserved,
      [view, content],
      "both detached targets are released"
    );
  });
});
