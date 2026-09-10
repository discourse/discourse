import { render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { stubPointerCapture } from "discourse/tests/helpers/ui-kit/pointer-gesture-helper";
import ConditionsFloatingPanel from "discourse/plugins/discourse-wireframe/discourse/components/editor/conditions/conditions-floating-panel";

const PANEL = ".wireframe-conditions-floating";
const HEADER = ".wireframe-conditions-floating__header";
const START = { x: 100, y: 100, width: 400, height: 300 };

function stubService(owner, name, stub) {
  owner.unregister(`service:${name}`);
  owner.register(`service:${name}`, stub, { instantiate: false });
}

async function press(target, x, y) {
  await triggerEvent(target, "pointerdown", {
    button: 0,
    pointerId: 1,
    clientX: x,
    clientY: y,
  });
}

async function move(target, x, y) {
  await triggerEvent(target, "pointermove", {
    pointerId: 1,
    clientX: x,
    clientY: y,
  });
}

module(
  "Integration | discourse-wireframe | Component | conditions-floating-panel",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      stubService(this.owner, "wireframe-edit-mode", { active: true });
      this.panel = this.owner.lookup("service:wireframe-conditions-panel");
      if (!this.panel.detached) {
        this.panel.toggleDetached();
      }
      this.panel.updateRect({ ...START });
    });

    test("dragging the header moves the panel by the pointer's travel", async function (assert) {
      await render(<template><ConditionsFloatingPanel /></template>);
      assert.dom(PANEL).exists();

      const { element: header } = stubPointerCapture(HEADER);
      await press(header, 150, 110);
      await move(header, 180, 115);

      assert.deepEqual(this.panel.rect, {
        x: 130,
        y: 105,
        width: 400,
        height: 300,
      });
      await triggerEvent(header, "pointerup", {
        pointerId: 1,
        clientX: 180,
        clientY: 115,
      });
      assert.deepEqual(this.panel.rect, {
        x: 130,
        y: 105,
        width: 400,
        height: 300,
      });
    });

    test("the panel stays inside the viewport", async function (assert) {
      await render(<template><ConditionsFloatingPanel /></template>);

      const { element: header } = stubPointerCapture(HEADER);
      await press(header, 150, 110);
      await move(header, -1000, -1000);

      assert.deepEqual(
        [this.panel.rect.x, this.panel.rect.y],
        [0, 0],
        "clamped at the top-left corner"
      );
    });

    test("pressing a header button does not start a drag", async function (assert) {
      await render(<template><ConditionsFloatingPanel /></template>);

      stubPointerCapture(HEADER);
      const button = document.querySelector(`${HEADER} button`);
      await press(button, 150, 110);
      await move(button, 180, 115);

      assert.deepEqual(this.panel.rect, START, "the panel did not move");
    });

    test("a cancelled gesture puts the panel back where it started", async function (assert) {
      await render(<template><ConditionsFloatingPanel /></template>);

      const { element: header } = stubPointerCapture(HEADER);
      await press(header, 150, 110);
      await move(header, 180, 115);
      await triggerEvent(header, "pointercancel", { pointerId: 1 });

      assert.deepEqual(this.panel.rect, START);
    });
  }
);
