import { module, test } from "qunit";
import sinon from "sinon";
import installLongPress from "../../../discourse/lib/long-press.js";

function press(element, type, at = { x: 10, y: 10 }, pointerType = "touch") {
  element.dispatchEvent(
    new PointerEvent(type, {
      bubbles: true,
      cancelable: true,
      pointerType,
      clientX: at.x,
      clientY: at.y,
    })
  );
}

module("Unit | Lib | long-press", function (hooks) {
  hooks.beforeEach(function () {
    this.clock = sinon.useFakeTimers();
    this.row = document.createElement("a");
    this.row.className = "row";
    document.body.append(this.row);
    this.pressed = [];
    this.uninstall = installLongPress(".row", (row) => this.pressed.push(row));
  });

  hooks.afterEach(function () {
    this.uninstall();
    this.row.remove();
    this.clock.restore();
  });

  test("fires after a held touch, and swallows the click that ends it", function (assert) {
    press(this.row, "pointerdown");
    this.clock.tick(499);
    assert.strictEqual(this.pressed.length, 0);

    this.clock.tick(1);
    assert.deepEqual(this.pressed, [this.row]);

    press(this.row, "pointerup");
    const click = new MouseEvent("click", { bubbles: true, cancelable: true });
    this.row.dispatchEvent(click);
    assert.true(click.defaultPrevented);
  });

  test("a short tap is an ordinary tap", function (assert) {
    press(this.row, "pointerdown");
    this.clock.tick(200);
    press(this.row, "pointerup");
    this.clock.tick(1000);

    const click = new MouseEvent("click", { bubbles: true, cancelable: true });
    this.row.dispatchEvent(click);

    assert.strictEqual(this.pressed.length, 0);
    assert.false(click.defaultPrevented);
  });

  test("moving the finger, as in a scroll, cancels it", function (assert) {
    press(this.row, "pointerdown", { x: 10, y: 10 });
    press(this.row, "pointermove", { x: 10, y: 30 });
    this.clock.tick(1000);

    assert.strictEqual(this.pressed.length, 0);
  });

  test("ignores the mouse", function (assert) {
    press(this.row, "pointerdown", undefined, "mouse");
    this.clock.tick(1000);

    assert.strictEqual(this.pressed.length, 0);
  });
});
