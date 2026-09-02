import { on } from "@ember/modifier";
import {
  clearRender,
  click,
  find,
  focus,
  render,
  triggerEvent,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import KeyValueStore from "discourse/lib/key-value-store";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import PanelDockChassis from "discourse/ui-kit/panel-dock/-internals/panel";

const STORE_NAMESPACE = "d_panel_dock_";

function installPointerCaptureSpy(element) {
  const captured = new Set();
  const released = [];

  element.setPointerCapture = (pointerId) => captured.add(pointerId);
  element.hasPointerCapture = (pointerId) => captured.has(pointerId);
  element.releasePointerCapture = (pointerId) => {
    captured.delete(pointerId);
    released.push(pointerId);
  };

  return { captured, released };
}

module(
  "Integration | Component | PanelDockChassis independent",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.store = new KeyValueStore(STORE_NAMESPACE);
      this.store.abandonLocal();
    });

    hooks.afterEach(function () {
      this.store.abandonLocal();
    });

    test("the open panel remains non-modal while the background is used", async function (assert) {
      this.isOpen = true;
      this.backgroundClicks = 0;
      this.useBackground = () => this.backgroundClicks++;

      await render(
        <template>
          <button
            class="background-button"
            type="button"
            {{on "click" this.useBackground}}
          >
            Use page
          </button>
          <input class="background-input" aria-label="Background input" />
          <PanelDockChassis @isOpen={{this.isOpen}}>
            <:body>Panel body</:body>
          </PanelDockChassis>
        </template>
      );

      await click(".background-button");
      await focus(".background-input");

      assert.strictEqual(
        this.backgroundClicks,
        1,
        "background controls remain interactive"
      );
      assert.strictEqual(
        document.activeElement,
        find(".background-input"),
        "focus is not trapped in the panel"
      );
      assert
        .dom(".d-panel-dock")
        .exists("using the page does not dismiss the panel");
      assert.strictEqual(
        getComputedStyle(find(".d-panel-dock-layer")).pointerEvents,
        "none",
        "the viewport layer passes pointer events through"
      );
      assert.strictEqual(
        getComputedStyle(find(".d-panel-dock")).pointerEvents,
        "auto",
        "the panel opts back into pointer interaction"
      );
    });

    test("size is exposed through a custom property and live separator values", async function (assert) {
      await render(
        <template>
          <PanelDockChassis @isOpen={{true}}>
            <:body>Panel body</:body>
          </PanelDockChassis>
        </template>
      );

      const panel = find(".d-panel-dock");

      assert.strictEqual(
        panel.style.getPropertyValue("--d-panel-dock-width"),
        "320px",
        "the initial size is published as a CSS custom property"
      );
      assert.strictEqual(
        panel.style.width,
        "",
        "the component does not publish an inline width"
      );
      assert.dom(".d-panel-dock__resizer").hasAttribute("role", "separator");
      assert.dom(".d-panel-dock__resizer").hasAttribute("tabindex", "0");
      assert.dom(".d-panel-dock__resizer").hasAttribute("aria-valuenow", "320");
      assert.dom(".d-panel-dock__resizer").hasAttribute("aria-valuemin", "240");
      assert.dom(".d-panel-dock__resizer").hasAttribute("aria-valuemax", "720");
    });

    test("keyboard resizing steps and clamps, but stores only with a storage key", async function (assert) {
      this.resizeEnds = [];
      this.recordResizeEnd = (width) => this.resizeEnds.push(width);
      const setObject = sinon.spy(KeyValueStore.prototype, "setObject");

      await render(
        <template>
          <PanelDockChassis @isOpen={{true}} @onResize={{this.recordResizeEnd}}>
            <:body>Panel body</:body>
          </PanelDockChassis>
        </template>
      );

      await triggerKeyEvent(".d-panel-dock__resizer", "keydown", "ArrowRight");
      await triggerKeyEvent(".d-panel-dock__resizer", "keyup", "ArrowRight");
      assert.dom(".d-panel-dock__resizer").hasAttribute("aria-valuenow", "336");

      await triggerKeyEvent(".d-panel-dock__resizer", "keydown", "End");
      await triggerKeyEvent(".d-panel-dock__resizer", "keyup", "End");
      await triggerKeyEvent(".d-panel-dock__resizer", "keydown", "ArrowRight");
      await triggerKeyEvent(".d-panel-dock__resizer", "keyup", "ArrowRight");
      assert.dom(".d-panel-dock__resizer").hasAttribute("aria-valuenow", "720");

      await triggerKeyEvent(".d-panel-dock__resizer", "keydown", "Home");
      await triggerKeyEvent(".d-panel-dock__resizer", "keyup", "Home");
      await triggerKeyEvent(".d-panel-dock__resizer", "keydown", "ArrowLeft");
      await triggerKeyEvent(".d-panel-dock__resizer", "keyup", "ArrowLeft");
      assert.dom(".d-panel-dock__resizer").hasAttribute("aria-valuenow", "240");
      assert.deepEqual(
        this.resizeEnds,
        [336, 720, 720, 240, 240],
        "each supported key commits its clamped value"
      );
      assert.false(
        setObject.called,
        "the persistence boundary is not called without a storage key"
      );
    });

    test("stored width is restored, clamped, and updated after a committed resize", async function (assert) {
      this.store.setObject({
        key: "independent-panel",
        value: { side: "start", width: 5000, height: 320 },
      });

      await render(
        <template>
          <PanelDockChassis @isOpen={{true}} @storageKey="independent-panel">
            <:body>Panel body</:body>
          </PanelDockChassis>
        </template>
      );

      assert.dom(".d-panel-dock__resizer").hasAttribute("aria-valuenow", "720");

      await triggerKeyEvent(".d-panel-dock__resizer", "keydown", "Home");
      await triggerKeyEvent(".d-panel-dock__resizer", "keyup", "Home");

      assert.deepEqual(
        this.store.getObject("independent-panel"),
        { mode: "docked", side: "start", width: 240, height: 320 },
        "the clamped committed width is persisted with the rest of the layout"
      );
    });

    test("pointer resizing ignores secondary buttons and mismatched pointer IDs", async function (assert) {
      this.resizeEnds = [];
      this.recordResizeEnd = (width) => this.resizeEnds.push(width);

      await render(
        <template>
          <PanelDockChassis @isOpen={{true}} @onResize={{this.recordResizeEnd}}>
            <:body>Panel body</:body>
          </PanelDockChassis>
        </template>
      );

      const resizer = find(".d-panel-dock__resizer");
      const capture = installPointerCaptureSpy(resizer);

      await triggerEvent(resizer, "pointerdown", {
        button: 2,
        clientX: 300,
        pointerId: 1,
      });
      assert.strictEqual(
        capture.captured.size,
        0,
        "a secondary button cannot capture"
      );

      await triggerEvent(resizer, "pointerdown", {
        button: 0,
        clientX: 300,
        pointerId: 7,
      });
      assert
        .dom(document.body)
        .hasClass(
          "d-resizing-ew",
          "the gesture holds the resize cursor on the body"
        );
      await triggerEvent(resizer, "pointerup", {
        button: 0,
        clientX: 700,
        pointerId: 99,
      });
      assert.deepEqual(
        this.resizeEnds,
        [],
        "a mismatched pointer cannot finish the drag"
      );
      assert.true(
        capture.captured.has(7),
        "the active pointer remains captured"
      );

      await triggerEvent(resizer, "pointerup", {
        button: 0,
        clientX: 900,
        pointerId: 7,
      });
      assert.deepEqual(
        this.resizeEnds,
        [720],
        "the matching pointer commits a clamped width"
      );
      assert.deepEqual(
        capture.released,
        [7],
        "the matching pointer capture is released"
      );
      assert
        .dom(document.body)
        .doesNotHaveClass(
          "d-resizing-ew",
          "the cursor is released with the gesture"
        );
    });

    test("a second pointer cannot replace an active drag or strand its capture", async function (assert) {
      this.resizeEnds = [];
      this.recordResizeEnd = (width) => this.resizeEnds.push(width);

      await render(
        <template>
          <PanelDockChassis @isOpen={{true}} @onResize={{this.recordResizeEnd}}>
            <:body>Panel body</:body>
          </PanelDockChassis>
        </template>
      );

      const resizer = find(".d-panel-dock__resizer");
      const capture = installPointerCaptureSpy(resizer);

      await triggerEvent(resizer, "pointerdown", {
        button: 0,
        clientX: 300,
        pointerId: 10,
      });
      await triggerEvent(resizer, "pointerdown", {
        button: 0,
        clientX: 400,
        pointerId: 20,
      });
      await triggerEvent(resizer, "pointerup", {
        button: 0,
        clientX: 350,
        pointerId: 10,
      });

      assert.deepEqual(
        this.resizeEnds,
        [370],
        "the pointer that began the drag remains the only pointer allowed to commit it"
      );
      assert.deepEqual(
        capture.released,
        [10],
        "the original pointer capture is not stranded by a second pointer"
      );
      assert.false(
        capture.captured.has(10),
        "the original capture is released"
      );
      assert.false(
        capture.captured.has(20),
        "the second pointer is never captured"
      );
    });

    test("destroying during a drag releases capture and removes transient listeners", async function (assert) {
      this.isOpen = true;
      this.resizeEnds = [];
      this.recordResizeEnd = (width) => this.resizeEnds.push(width);

      await render(
        <template>
          <PanelDockChassis
            @isOpen={{this.isOpen}}
            @onResize={{this.recordResizeEnd}}
          >
            <:body>Panel body</:body>
          </PanelDockChassis>
        </template>
      );

      const detachedResizer = find(".d-panel-dock__resizer");
      const capture = installPointerCaptureSpy(detachedResizer);

      await triggerEvent(detachedResizer, "pointerdown", {
        button: 0,
        clientX: 300,
        pointerId: 42,
      });

      await clearRender();

      assert.deepEqual(
        capture.released,
        [42],
        "destroy releases the active capture"
      );

      await triggerEvent(detachedResizer, "pointermove", {
        clientX: 500,
        pointerId: 42,
      });
      await triggerEvent(detachedResizer, "pointerup", {
        clientX: 500,
        pointerId: 42,
      });

      assert.deepEqual(
        this.resizeEnds,
        [],
        "detached pointer listeners cannot commit a resize after destroy"
      );
    });
  }
);

module(
  "Integration | Component | PanelDockChassis verification",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.store = new KeyValueStore(STORE_NAMESPACE);
      this.store.abandonLocal();
    });

    hooks.afterEach(function () {
      this.store.abandonLocal();
      sinon.restore();
    });

    test("bottom pointer resizing preserves a width resized on another side", async function (assert) {
      await render(
        <template>
          <PanelDockChassis
            @isOpen={{true}}
            @dockable={{true}}
            @storageKey="verification-panel"
          >
            <:header>Panel title</:header>
          </PanelDockChassis>
        </template>
      );

      await click(".d-panel-dock__dock-button.--end");

      let resizer = find(".d-panel-dock__resizer");
      installPointerCaptureSpy(resizer);
      await triggerEvent(resizer, "pointerdown", {
        button: 0,
        clientX: 500,
        pointerId: 1,
      });
      await triggerEvent(resizer, "pointerup", {
        button: 0,
        clientX: 420,
        pointerId: 1,
      });

      await click(".d-panel-dock__dock-button.--bottom");

      resizer = find(".d-panel-dock__resizer");
      installPointerCaptureSpy(resizer);
      await triggerEvent(resizer, "pointerdown", {
        button: 0,
        clientX: 100,
        clientY: 500,
        pointerId: 2,
      });
      await triggerEvent(resizer, "pointerup", {
        button: 0,
        clientX: 900,
        clientY: 420,
        pointerId: 2,
      });

      const panel = find(".d-panel-dock");
      assert.strictEqual(
        panel.style.getPropertyValue("--d-panel-dock-width"),
        "400px",
        "the end-dock drag grows the width toward the start"
      );
      assert.strictEqual(
        panel.style.getPropertyValue("--d-panel-dock-height"),
        "400px",
        "the bottom-dock drag grows the height upward and ignores clientX"
      );
      assert.deepEqual(
        this.store.getObject("verification-panel"),
        { mode: "docked", side: "bottom", width: 400, height: 400 },
        "resizing one axis does not discard the other axis's size"
      );
    });

    test("an end dock follows the logical inline axis under RTL", async function (assert) {
      this.resizeEnds = [];
      this.recordResizeEnd = (width) => this.resizeEnds.push(width);

      await render(
        <template>
          <div dir="rtl">
            <PanelDockChassis
              @isOpen={{true}}
              @defaultSide="end"
              @onResize={{this.recordResizeEnd}}
            />
          </div>
        </template>
      );

      const resizer = find(".d-panel-dock__resizer");
      installPointerCaptureSpy(resizer);
      await triggerEvent(resizer, "pointerdown", {
        button: 0,
        clientX: 500,
        pointerId: 3,
      });
      await triggerEvent(resizer, "pointerup", {
        button: 0,
        clientX: 580,
        pointerId: 3,
      });

      assert.deepEqual(
        this.resizeEnds,
        [400],
        "moving right grows an end-docked panel because logical end is left in RTL"
      );
      assert
        .dom(".d-panel-dock")
        .hasClass("--dock-end", "the logical end modifier remains active");
    });

    test("partially valid and wrongly typed stored layouts are ignored", async function (assert) {
      const invalidLayouts = [
        { side: "bottom" },
        { side: "bottom", width: "480", height: 250 },
        { side: "bottom", width: 480, height: "250" },
        { side: "top", width: 480, height: 250 },
      ];

      for (const [index, value] of invalidLayouts.entries()) {
        const key = `invalid-layout-${index}`;
        this.store.setObject({ key, value });
        this.storageKey = key;

        await render(
          <template>
            <PanelDockChassis
              @isOpen={{true}}
              @storageKey={{this.storageKey}}
            />
          </template>
        );

        assert
          .dom(".d-panel-dock")
          .hasClass(
            "--dock-start",
            `invalid layout ${index + 1} uses the side fallback`
          );
        assert
          .dom(".d-panel-dock__resizer")
          .hasAttribute(
            "aria-valuenow",
            "320",
            `invalid layout ${index + 1} uses the size fallback`
          );

        await clearRender();
      }
    });

    test("a stored size is clamped to a viewport-derived maximum in ARIA", async function (assert) {
      sinon.stub(window, "innerWidth").value(400);
      this.store.setObject({
        key: "narrow-viewport",
        value: { side: "end", width: 700, height: 320 },
      });

      await render(
        <template>
          <PanelDockChassis @isOpen={{true}} @storageKey="narrow-viewport" />
        </template>
      );

      assert
        .dom(".d-panel-dock__resizer")
        .hasAttribute("aria-valuemax", "360", "ARIA exposes the viewport cap");
      assert
        .dom(".d-panel-dock__resizer")
        .hasAttribute(
          "aria-valuenow",
          "360",
          "ARIA reports the clamped rendered width, not the oversized stored width"
        );
    });

    test("dockable renders its picker without a header block", async function (assert) {
      await render(
        <template>
          <PanelDockChassis @isOpen={{true}} @dockable={{true}}>
            <:actions><button
                type="button"
                class="verification-action"
              >Close</button></:actions>
          </PanelDockChassis>
        </template>
      );

      assert
        .dom(".d-panel-dock__header")
        .exists("dockable creates the header that owns its controls");
      assert
        .dom(".d-panel-dock__dock-button")
        .exists(
          { count: 3 },
          "all dock choices remain available without a title"
        );
      assert
        .dom(".verification-action")
        .exists("the actions block is not discarded when the title is omitted");
    });
  }
);
