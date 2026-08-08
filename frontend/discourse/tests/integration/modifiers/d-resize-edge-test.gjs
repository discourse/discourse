import { tracked } from "@glimmer/tracking";
import {
  clearRender,
  find,
  render,
  triggerEvent,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dResizeEdge from "discourse/ui-kit/modifiers/d-resize-edge";

const EDGE = ".resize-edge";

/**
 * Replaces the pointer capture API with an observable stand-in.
 *
 * The real methods reject synthetic pointer IDs, which is all a test can
 * dispatch, so capture has to be recorded rather than performed.
 */
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

class Harness {
  @tracked value;

  resizes = [];
  resizeEnds = [];

  constructor(value = 300) {
    this.value = value;
    this.onResize = (size) => {
      this.resizes.push(size);
      this.value = size;
    };
    this.onResizeEnd = (size) => this.resizeEnds.push(size);
  }
}

module("Integration | Modifier | d-resize-edge", function (hooks) {
  setupRenderingTest(hooks);

  test("a pointer drag reports a clamped size and commits once", async function (assert) {
    const state = new Harness();

    await render(
      <template>
        <div
          class="resize-edge"
          {{dResizeEdge
            value=state.value
            min=240
            max=720
            onResize=state.onResize
            onResizeEnd=state.onResizeEnd
          }}
        ></div>
      </template>
    );

    const edge = find(EDGE);
    installPointerCaptureSpy(edge);

    await triggerEvent(edge, "pointerdown", {
      button: 0,
      clientX: 300,
      pointerId: 1,
    });
    await triggerEvent(edge, "pointerup", {
      button: 0,
      clientX: 380,
      pointerId: 1,
    });

    assert.deepEqual(
      state.resizeEnds,
      [380],
      "the size follows the pointer away from the start edge"
    );

    await triggerEvent(edge, "pointerdown", {
      button: 0,
      clientX: 380,
      pointerId: 2,
    });
    await triggerEvent(edge, "pointerup", {
      button: 0,
      clientX: 2000,
      pointerId: 2,
    });

    assert.deepEqual(
      state.resizeEnds,
      [380, 720],
      "a drag past the maximum is clamped to it"
    );
  });

  test("the element is opted out of browser touch gestures", async function (assert) {
    const state = new Harness();

    await render(
      <template>
        <div
          class="resize-edge"
          {{dResizeEdge value=state.value min=240 max=720}}
        ></div>
      </template>
    );

    assert
      .dom(EDGE)
      .hasStyle(
        { touchAction: "none" },
        "a touch drag is not claimed by the browser as a scroll"
      );
  });

  test("a secondary button never starts a drag", async function (assert) {
    const state = new Harness();

    await render(
      <template>
        <div
          class="resize-edge"
          {{dResizeEdge
            value=state.value
            min=240
            max=720
            onResizeEnd=state.onResizeEnd
          }}
        ></div>
      </template>
    );

    const edge = find(EDGE);
    const capture = installPointerCaptureSpy(edge);

    await triggerEvent(edge, "pointerdown", {
      button: 2,
      clientX: 300,
      pointerId: 1,
    });

    assert.strictEqual(capture.captured.size, 0, "nothing is captured");

    await triggerEvent(edge, "pointerup", {
      button: 2,
      clientX: 500,
      pointerId: 1,
    });

    assert.deepEqual(state.resizeEnds, [], "no size is committed");
  });

  test("only the pointer that began a drag may commit it", async function (assert) {
    const state = new Harness();

    await render(
      <template>
        <div
          class="resize-edge"
          {{dResizeEdge
            value=state.value
            min=240
            max=720
            onResizeEnd=state.onResizeEnd
          }}
        ></div>
      </template>
    );

    const edge = find(EDGE);
    const capture = installPointerCaptureSpy(edge);

    await triggerEvent(edge, "pointerdown", {
      button: 0,
      clientX: 300,
      pointerId: 7,
    });
    await triggerEvent(edge, "pointerup", {
      button: 0,
      clientX: 700,
      pointerId: 99,
    });

    assert.deepEqual(
      state.resizeEnds,
      [],
      "a mismatched pointer cannot finish the drag"
    );
    assert.true(capture.captured.has(7), "the active pointer stays captured");

    await triggerEvent(edge, "pointerup", {
      button: 0,
      clientX: 400,
      pointerId: 7,
    });

    assert.deepEqual(state.resizeEnds, [400], "the matching pointer commits");
    assert.deepEqual(capture.released, [7], "its capture is released");
  });

  test("a second pointer cannot replace an active drag or strand its capture", async function (assert) {
    const state = new Harness();

    await render(
      <template>
        <div
          class="resize-edge"
          {{dResizeEdge
            value=state.value
            min=240
            max=720
            onResizeEnd=state.onResizeEnd
          }}
        ></div>
      </template>
    );

    const edge = find(EDGE);
    const capture = installPointerCaptureSpy(edge);

    await triggerEvent(edge, "pointerdown", {
      button: 0,
      clientX: 300,
      pointerId: 10,
    });
    await triggerEvent(edge, "pointerdown", {
      button: 0,
      clientX: 400,
      pointerId: 20,
    });
    await triggerEvent(edge, "pointerup", {
      button: 0,
      clientX: 350,
      pointerId: 10,
    });

    assert.deepEqual(
      state.resizeEnds,
      [350],
      "the original pointer is still the one measured from"
    );
    assert.deepEqual(capture.released, [10], "its capture is not stranded");
    assert.false(
      capture.captured.has(20),
      "the second pointer is never captured"
    );
  });

  test("teardown during a drag releases capture", async function (assert) {
    const state = new Harness();

    await render(
      <template>
        <div
          class="resize-edge"
          {{dResizeEdge
            value=state.value
            min=240
            max=720
            onResizeEnd=state.onResizeEnd
          }}
        ></div>
      </template>
    );

    const edge = find(EDGE);
    const capture = installPointerCaptureSpy(edge);

    await triggerEvent(edge, "pointerdown", {
      button: 0,
      clientX: 300,
      pointerId: 3,
    });

    await clearRender();

    assert.deepEqual(capture.released, [3], "the capture is released");

    await triggerEvent(edge, "pointerup", {
      button: 0,
      clientX: 600,
      pointerId: 3,
    });

    assert.deepEqual(
      state.resizeEnds,
      [],
      "the detached edge no longer commits sizes"
    );
  });

  test("arrow keys step the size and Home and End jump to the bounds", async function (assert) {
    const state = new Harness();

    await render(
      <template>
        <div
          class="resize-edge"
          {{dResizeEdge
            value=state.value
            min=240
            max=720
            onResize=state.onResize
            onResizeEnd=state.onResizeEnd
          }}
        ></div>
      </template>
    );

    await triggerKeyEvent(EDGE, "keydown", "ArrowRight");
    assert.strictEqual(
      state.value,
      316,
      "ArrowRight grows a start-docked edge"
    );

    await triggerKeyEvent(EDGE, "keydown", "ArrowLeft");
    assert.strictEqual(state.value, 300, "ArrowLeft shrinks it again");

    await triggerKeyEvent(EDGE, "keydown", "End");
    assert.strictEqual(state.value, 720, "End jumps to the maximum");

    await triggerKeyEvent(EDGE, "keydown", "ArrowRight");
    assert.strictEqual(state.value, 720, "growing past the maximum is clamped");

    await triggerKeyEvent(EDGE, "keydown", "Home");
    assert.strictEqual(state.value, 240, "Home jumps to the minimum");

    await triggerKeyEvent(EDGE, "keydown", "ArrowLeft");
    assert.strictEqual(
      state.value,
      240,
      "shrinking past the minimum is clamped"
    );

    assert.strictEqual(
      state.resizeEnds.length,
      state.resizes.length,
      "every keyboard step is committed as well as previewed"
    );
  });

  test("an unhandled key is left alone", async function (assert) {
    const state = new Harness();

    await render(
      <template>
        <div
          class="resize-edge"
          {{dResizeEdge
            value=state.value
            min=240
            max=720
            onResize=state.onResize
          }}
        ></div>
      </template>
    );

    await triggerKeyEvent(EDGE, "keydown", "ArrowUp");

    assert.deepEqual(
      state.resizes,
      [],
      "the vertical arrows do nothing on a horizontal edge"
    );
  });

  test("an end-docked edge inverts the growth direction", async function (assert) {
    const state = new Harness();

    await render(
      <template>
        <div
          class="resize-edge"
          {{dResizeEdge
            value=state.value
            min=240
            max=720
            side="end"
            onResize=state.onResize
            onResizeEnd=state.onResizeEnd
          }}
        ></div>
      </template>
    );

    const edge = find(EDGE);
    installPointerCaptureSpy(edge);

    await triggerEvent(edge, "pointerdown", {
      button: 0,
      clientX: 300,
      pointerId: 1,
    });
    await triggerEvent(edge, "pointerup", {
      button: 0,
      clientX: 220,
      pointerId: 1,
    });

    assert.deepEqual(
      state.resizeEnds,
      [380],
      "moving toward the start edge grows an end-docked element"
    );

    await triggerKeyEvent(EDGE, "keydown", "ArrowLeft");
    assert.strictEqual(state.value, 396, "ArrowLeft grows it too");
  });

  test("a right-to-left writing direction flips the horizontal axis only", async function (assert) {
    const horizontal = new Harness();
    const vertical = new Harness();

    await render(
      <template>
        <div dir="rtl">
          <div
            class="resize-edge"
            {{dResizeEdge
              value=horizontal.value
              min=240
              max=720
              onResizeEnd=horizontal.onResizeEnd
            }}
          ></div>
          <div
            class="vertical-edge"
            {{dResizeEdge
              value=vertical.value
              min=240
              max=720
              axis="vertical"
              onResizeEnd=vertical.onResizeEnd
            }}
          ></div>
        </div>
      </template>
    );

    const edge = find(EDGE);
    installPointerCaptureSpy(edge);

    await triggerEvent(edge, "pointerdown", {
      button: 0,
      clientX: 300,
      pointerId: 1,
    });
    await triggerEvent(edge, "pointerup", {
      button: 0,
      clientX: 340,
      pointerId: 1,
    });

    assert.deepEqual(
      horizontal.resizeEnds,
      [260],
      "moving right shrinks a start-docked element under RTL"
    );

    const verticalEdge = find(".vertical-edge");
    installPointerCaptureSpy(verticalEdge);

    await triggerEvent(verticalEdge, "pointerdown", {
      button: 0,
      clientY: 300,
      pointerId: 2,
    });
    await triggerEvent(verticalEdge, "pointerup", {
      button: 0,
      clientY: 380,
      pointerId: 2,
    });

    assert.deepEqual(
      vertical.resizeEnds,
      [380],
      "the vertical axis is unaffected by the writing direction"
    );
  });

  test("a vertical edge follows the pointer and the vertical arrows", async function (assert) {
    const state = new Harness();

    await render(
      <template>
        <div
          class="resize-edge"
          {{dResizeEdge
            value=state.value
            min=240
            max=720
            axis="vertical"
            onResize=state.onResize
            onResizeEnd=state.onResizeEnd
          }}
        ></div>
      </template>
    );

    const edge = find(EDGE);
    installPointerCaptureSpy(edge);

    await triggerEvent(edge, "pointerdown", {
      button: 0,
      clientX: 500,
      clientY: 300,
      pointerId: 1,
    });
    await triggerEvent(edge, "pointerup", {
      button: 0,
      clientX: 900,
      clientY: 360,
      pointerId: 1,
    });

    assert.deepEqual(
      state.resizeEnds,
      [360],
      "the vertical coordinate drives the size and the horizontal one is ignored"
    );

    await triggerKeyEvent(EDGE, "keydown", "ArrowDown");
    assert.strictEqual(state.value, 376, "ArrowDown grows a top-docked edge");

    await triggerKeyEvent(EDGE, "keydown", "ArrowUp");
    assert.strictEqual(state.value, 360, "ArrowUp shrinks it");

    await triggerKeyEvent(EDGE, "keydown", "ArrowRight");
    assert.strictEqual(
      state.value,
      360,
      "the horizontal arrows do nothing on a vertical edge"
    );
  });

  test("a bottom-docked vertical edge grows upward", async function (assert) {
    const state = new Harness(0);

    await render(
      <template>
        <div
          class="resize-edge"
          {{dResizeEdge
            value=state.value
            min=0
            max=400
            axis="vertical"
            side="end"
            onResize=state.onResize
            onResizeEnd=state.onResizeEnd
          }}
        ></div>
      </template>
    );

    const edge = find(EDGE);
    installPointerCaptureSpy(edge);

    await triggerEvent(edge, "pointerdown", {
      button: 0,
      clientY: 500,
      pointerId: 1,
    });
    await triggerEvent(edge, "pointerup", {
      button: 0,
      clientY: 380,
      pointerId: 1,
    });

    assert.deepEqual(
      state.resizeEnds,
      [120],
      "dragging up grows an element docked to the bottom"
    );

    await triggerKeyEvent(EDGE, "keydown", "ArrowUp");
    assert.strictEqual(state.value, 136, "ArrowUp grows it too");
  });
});
