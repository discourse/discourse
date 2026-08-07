import {
  find,
  render,
  triggerEvent,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DResizeSeparator from "discourse/ui-kit/d-resize-separator";

/**
 * Pointer capture rejects a pointer ID that was never real, so the gesture would
 * refuse to start on a synthetic press. Stubbing it leaves the rest genuine.
 *
 * @param {string} selector - The separator that will receive the press.
 * @returns {HTMLElement} That element.
 */
function pressable(selector) {
  const element = find(selector);
  const captured = new Set();
  element.setPointerCapture = (pointerId) => captured.add(pointerId);
  element.hasPointerCapture = (pointerId) => captured.has(pointerId);
  element.releasePointerCapture = (pointerId) => captured.delete(pointerId);
  return element;
}

module("Integration | ui-kit | DResizeSeparator", function (hooks) {
  setupRenderingTest(hooks);

  test("a vertical resize is announced as a horizontal separator", async function (assert) {
    const size = () => 300;
    const min = () => 100;
    const max = () => 500;

    await render(
      <template>
        <DResizeSeparator
          @axis="vertical"
          @value={{size}}
          @min={{min}}
          @max={{max}}
          @label="Resize the thing"
          class="my-handle"
        />
      </template>
    );

    assert
      .dom(".my-handle")
      .hasAttribute("role", "separator", "it is a separator")
      // A separator between vertically stacked regions is itself a horizontal
      // bar, so the orientation is the opposite of the axis being resized.
      .hasAttribute("aria-orientation", "horizontal")
      .hasAttribute("tabindex", "0", "it is a single tab stop")
      .hasAttribute("aria-label", "Resize the thing")
      .hasAttribute("aria-valuenow", "300")
      .hasAttribute("aria-valuemin", "100")
      .hasAttribute("aria-valuemax", "500");
  });

  test("carries a styling hook that does not depend on the ARIA", async function (assert) {
    const size = () => 300;

    await render(
      <template>
        <DResizeSeparator
          @axis="vertical"
          @value={{size}}
          @min={{100}}
          @max={{500}}
          @label="Resize the thing"
          class="my-handle"
        />
      </template>
    );

    // Stylesheets key off these, never off `role` or `aria-orientation`: those are
    // what the element promises assistive technology, and a consumer may override
    // them through attributes without meaning to restyle anything.
    assert
      .dom(".my-handle")
      .hasAttribute("data-resize-separator", "")
      .hasAttribute("data-resize-axis", "vertical");
  });

  test("the styling hook names the axis being resized, not the bar's direction", async function (assert) {
    const size = () => 300;

    await render(
      <template>
        <DResizeSeparator
          @axis="horizontal"
          @value={{size}}
          @min={{100}}
          @max={{500}}
          @label="Resize the panel"
          class="my-handle"
        />
      </template>
    );

    assert.dom(".my-handle").hasAttribute("data-resize-axis", "horizontal");
    assert
      .dom(".my-handle")
      .hasAttribute(
        "aria-orientation",
        "vertical",
        "which is the opposite of what it announces, so the two must not be conflated"
      );
  });

  test("a horizontal resize is announced as a vertical separator", async function (assert) {
    const size = () => 240;

    await render(
      <template>
        <DResizeSeparator
          @axis="horizontal"
          @value={{size}}
          @min={{0}}
          @max={{800}}
          @label="Resize the panel"
          class="my-handle"
        />
      </template>
    );

    assert
      .dom(".my-handle")
      .hasAttribute("aria-orientation", "vertical")
      .hasAttribute("aria-valuenow", "240")
      .hasAttribute("aria-valuemin", "0", "a plain number is accepted too")
      .hasAttribute("aria-valuemax", "800");
  });

  test("nothing is announced as the size until it has been measured", async function (assert) {
    const unmeasured = () => null;

    await render(
      <template>
        <DResizeSeparator
          @axis="vertical"
          @value={{unmeasured}}
          @min={{100}}
          @max={{500}}
          @label="Resize the thing"
          class="my-handle"
        />
      </template>
    );

    // Reporting zero would claim the box has no height. An absent value says
    // "not known yet", which is the honest answer before a measurement lands.
    assert.dom(".my-handle").doesNotHaveAttribute("aria-valuenow");
    assert.dom(".my-handle").hasAttribute("aria-valuemin", "100");
  });

  test("a pointer drag reports the new size and updates what is announced", async function (assert) {
    const reports = [];
    let current = 300;
    const size = () => current;
    const onResize = (next) => {
      current = next;
      reports.push(`resize:${next}`);
    };
    const onResizeEnd = (next) => reports.push(`end:${next}`);

    await render(
      <template>
        <DResizeSeparator
          @axis="vertical"
          @side="end"
          @value={{size}}
          @min={{100}}
          @max={{500}}
          @label="Resize the thing"
          @onResize={{onResize}}
          @onResizeEnd={{onResizeEnd}}
          class="my-handle"
        />
      </template>
    );

    const handle = pressable(".my-handle");
    await triggerEvent(handle, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 0,
      clientY: 400,
    });
    // Docked against the block-end, so dragging up grows the box.
    await triggerEvent(handle, "pointermove", {
      pointerId: 1,
      clientX: 0,
      clientY: 360,
    });
    await triggerEvent(handle, "pointerup", {
      pointerId: 1,
      clientX: 0,
      clientY: 360,
    });

    // Asserted on the outcome rather than the cadence: how many previews precede a
    // commit is the modifier's contract and is pinned by its own suite.
    assert.deepEqual(
      reports.filter((report) => report.startsWith("end:")),
      ["end:340"],
      "the gesture commits exactly once, at the size it ended on"
    );
    assert.true(
      reports.every((report) => report.endsWith(":340")),
      "the consumer is told the size, not the pointer position"
    );
    assert
      .dom(".my-handle")
      .hasAttribute(
        "aria-valuenow",
        "340",
        "and the announced size follows without the consumer wiring it"
      );
  });

  test("the cursor is held on the page for the length of the gesture", async function (assert) {
    const size = () => 300;

    await render(
      <template>
        <DResizeSeparator
          @axis="vertical"
          @value={{size}}
          @min={{100}}
          @max={{500}}
          @label="Resize the thing"
          class="my-handle"
        />
      </template>
    );

    const handle = pressable(".my-handle");

    assert.dom(document.body).doesNotHaveClass("d-resizing-ns");

    await triggerEvent(handle, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 0,
      clientY: 400,
    });

    // Keeping the cursor of the element a drag began on is engine-dependent, so
    // the intent is stated on the page for as long as the gesture lasts.
    assert
      .dom(document.body)
      .hasClass("d-resizing-ns", "the axis decides which cursor is held");

    await triggerEvent(handle, "pointerup", { pointerId: 1, clientY: 400 });

    assert
      .dom(document.body)
      .doesNotHaveClass("d-resizing-ns", "and it is given back on release");
  });

  test("a horizontal gesture holds the other cursor", async function (assert) {
    const size = () => 300;

    await render(
      <template>
        <DResizeSeparator
          @axis="horizontal"
          @value={{size}}
          @min={{100}}
          @max={{500}}
          @label="Resize the panel"
          class="my-handle"
        />
      </template>
    );

    const handle = pressable(".my-handle");
    await triggerEvent(handle, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 200,
      clientY: 0,
    });

    assert.dom(document.body).hasClass("d-resizing-ew");
    assert.dom(document.body).doesNotHaveClass("d-resizing-ns");

    await triggerEvent(handle, "pointerup", { pointerId: 1, clientX: 200 });
    assert.dom(document.body).doesNotHaveClass("d-resizing-ew");
  });

  test("arrow keys resize without a pointer", async function (assert) {
    const reports = [];
    let current = 300;
    const size = () => current;
    const onResize = (next) => {
      current = next;
      reports.push(next);
    };

    await render(
      <template>
        <DResizeSeparator
          @axis="vertical"
          @side="end"
          @value={{size}}
          @min={{100}}
          @max={{500}}
          @label="Resize the thing"
          @onResize={{onResize}}
          class="my-handle"
        />
      </template>
    );

    await triggerKeyEvent(".my-handle", "keydown", "ArrowUp");

    assert.strictEqual(reports.length, 1, "a key press resizes once");
    assert
      .dom(".my-handle")
      .hasAttribute(
        "aria-valuenow",
        String(reports[0]),
        "the keyboard path keeps the announced size in step too"
      );
  });

  test("refresh re-reads the size for changes the gesture cannot see", async function (assert) {
    let current = 300;
    const size = () => current;
    let api;
    const onRegisterApi = (handle) => (api = handle);

    await render(
      <template>
        <DResizeSeparator
          @axis="vertical"
          @value={{size}}
          @min={{100}}
          @max={{500}}
          @label="Resize the thing"
          @onRegisterApi={{onRegisterApi}}
          class="my-handle"
        />
      </template>
    );

    assert.dom(".my-handle").hasAttribute("aria-valuenow", "300");

    // The box can change size for reasons that never touch the separator, and the
    // owner is the only one who knows when that happened.
    current = 420;
    api.refresh();
    await triggerEvent(".my-handle", "focus");

    assert
      .dom(".my-handle")
      .hasAttribute("aria-valuenow", "420", "the announced size catches up");
  });
});
