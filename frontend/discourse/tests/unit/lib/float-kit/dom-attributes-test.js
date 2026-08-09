import { module, test } from "qunit";
import sinon from "sinon";
import DOMAttributes from "discourse/float-kit/components/d-sheet/dom-attributes";

module("Unit | Lib | float-kit | d-sheet DOM attributes", function (hooks) {
  let clock;

  hooks.beforeEach(function () {
    clock = sinon.useFakeTimers();
  });

  hooks.afterEach(function () {
    clock.restore();
  });

  test("temporary overflow restoration stays bound to its element", function (assert) {
    const first = document.createElement("div");
    const replacement = document.createElement("div");
    const controller = { scrollContainer: first };
    const attributes = new DOMAttributes(controller);

    first.style.setProperty("overflow", "scroll", "important");
    attributes.temporarilyHideOverflow(10);
    controller.scrollContainer = replacement;
    clock.tick(10);

    assert.strictEqual(
      first.style.getPropertyValue("overflow"),
      "scroll",
      "the original element is restored"
    );
    assert.strictEqual(
      first.style.getPropertyPriority("overflow"),
      "important",
      "the original priority is preserved"
    );
    assert.strictEqual(
      replacement.style.getPropertyValue("overflow"),
      "",
      "a replacement element is not mutated"
    );
  });

  test("cleanup restores a pending overflow workaround", function (assert) {
    const element = document.createElement("div");
    const attributes = new DOMAttributes({ scrollContainer: element });

    attributes.temporarilyHideOverflow(10);
    attributes.cleanup();

    assert.strictEqual(
      element.style.getPropertyValue("overflow"),
      "",
      "cleanup removes the owned inline style"
    );

    clock.tick(10);
    assert.strictEqual(
      element.style.getPropertyValue("overflow"),
      "",
      "the cancelled callback cannot mutate the element"
    );
  });
});
