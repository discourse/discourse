import { tracked } from "@glimmer/tracking";
import {
  clearRender,
  find,
  render,
  settled,
  triggerEvent,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { stubPointerCapture } from "discourse/tests/helpers/ui-kit/pointer-gesture-helper";
import dResizeEdge from "discourse/ui-kit/modifiers/d-resize-edge";

const EDGE = ".resize-edge";

/**
 * Records what the modifier reported, and holds the size it reports against.
 *
 * The size is tracked because the modifier reads it back at the start of every
 * gesture, so a test that drags twice has to see the first drag's result.
 */
class Harness {
  @tracked value;

  resizes = [];
  resizeEnds = [];
  resizeStarts = 0;

  constructor(value = 300) {
    this.value = value;
    this.onResizeStart = () => this.resizeStarts++;
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
    stubPointerCapture(edge);

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

  test("grippie regression clamp conflict pointer honors minimum", async function (assert) {
    const state = new Harness(220);

    await render(
      <template>
        <div
          class="resize-edge"
          {{dResizeEdge
            value=state.value
            min=255
            max=190
            onResize=state.onResize
            onResizeEnd=state.onResizeEnd
          }}
        ></div>
      </template>
    );

    const edge = find(EDGE);
    stubPointerCapture(edge);

    await triggerEvent(edge, "pointerdown", {
      button: 0,
      clientX: 220,
      pointerId: 1,
    });
    await triggerEvent(edge, "pointerup", {
      button: 0,
      clientX: 230,
      pointerId: 1,
    });

    assert.deepEqual(
      state.resizeEnds,
      [255],
      "a pointer clamp never reports a value below the minimum"
    );
  });

  test("grippie regression clamp conflict keyboard honors minimum", async function (assert) {
    const state = new Harness(220);

    await render(
      <template>
        <div
          class="resize-edge"
          {{dResizeEdge
            value=state.value
            min=255
            max=190
            onResize=state.onResize
            onResizeEnd=state.onResizeEnd
          }}
        ></div>
      </template>
    );

    await triggerKeyEvent(EDGE, "keydown", "ArrowRight");
    await triggerKeyEvent(EDGE, "keyup", "ArrowRight");

    assert.deepEqual(
      state.resizeEnds,
      [255],
      "a keyboard clamp never reports a value below the minimum"
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
    const capture = stubPointerCapture(edge);

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
    const capture = stubPointerCapture(edge);

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
    const capture = stubPointerCapture(edge);

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
    const capture = stubPointerCapture(edge);

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

    const press = async (key) => {
      await triggerKeyEvent(EDGE, "keydown", key);
      await triggerKeyEvent(EDGE, "keyup", key);
    };

    await press("ArrowRight");
    assert.strictEqual(
      state.value,
      316,
      "ArrowRight grows a start-docked edge"
    );

    await press("ArrowLeft");
    assert.strictEqual(state.value, 300, "ArrowLeft shrinks it again");

    await press("End");
    assert.strictEqual(state.value, 720, "End jumps to the maximum");

    await press("ArrowRight");
    assert.strictEqual(state.value, 720, "growing past the maximum is clamped");

    await press("Home");
    assert.strictEqual(state.value, 240, "Home jumps to the minimum");

    await press("ArrowLeft");
    assert.strictEqual(
      state.value,
      240,
      "shrinking past the minimum is clamped"
    );

    assert.strictEqual(
      state.resizeEnds.length,
      state.resizes.length,
      "every discrete keyboard step is committed as well as previewed"
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

  test("a modified arrow key is left to the browser", async function (assert) {
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

    // Each of these is a browser or OS binding a user expects to work while the
    // separator happens to hold focus: back, word-wise motion, and selection.
    for (const modifier of ["metaKey", "ctrlKey", "altKey", "shiftKey"]) {
      await triggerKeyEvent(EDGE, "keydown", "ArrowLeft", {
        [modifier]: true,
      });
    }

    assert.deepEqual(
      state.resizes,
      [],
      "a modified arrow does not resize, so the binding it belongs to still runs"
    );
  });

  test("a press that never moves reports nothing", async function (assert) {
    const state = new Harness();

    await render(
      <template>
        <div
          class="resize-edge"
          {{dResizeEdge
            value=state.value
            min=240
            max=720
            onResizeStart=state.onResizeStart
            onResize=state.onResize
            onResizeEnd=state.onResizeEnd
          }}
        ></div>
      </template>
    );
    stubPointerCapture(EDGE);

    await triggerEvent(EDGE, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 300,
      clientY: 0,
    });
    await triggerEvent(EDGE, "pointerup", {
      pointerId: 1,
      clientX: 300,
      clientY: 0,
    });

    assert.deepEqual(
      state.resizes,
      [],
      "a click is not a resize, so nothing is previewed"
    );
    assert.deepEqual(
      state.resizeEnds,
      [],
      "and nothing is committed, so a consumer does not persist a size the user never chose"
    );
    assert.strictEqual(
      state.resizeStarts,
      0,
      "and no gesture is opened, so nothing is left waiting to be closed"
    );
  });

  test("a gesture that reports opens and closes exactly once", async function (assert) {
    const state = new Harness();

    await render(
      <template>
        <div
          class="resize-edge"
          {{dResizeEdge
            axis="vertical"
            value=state.value
            min=240
            max=720
            onResizeStart=state.onResizeStart
            onResize=state.onResize
            onResizeEnd=state.onResizeEnd
          }}
        ></div>
      </template>
    );

    const edge = find(EDGE);
    stubPointerCapture(edge);

    // Sideways on a vertical resize: the projected coordinate never changes, so
    // the release lands on the press coordinate even though the gesture reported.
    await triggerEvent(edge, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 100,
      clientY: 300,
    });
    await triggerEvent(edge, "pointermove", {
      button: 0,
      pointerId: 1,
      clientX: 200,
      clientY: 300,
    });
    await new Promise((resolve) => requestAnimationFrame(resolve));
    await triggerEvent(edge, "pointerup", {
      pointerId: 1,
      clientX: 200,
      clientY: 300,
    });

    assert.strictEqual(state.resizeStarts, 1, "the gesture opened once");
    assert.strictEqual(
      state.resizeEnds.length,
      1,
      "and closed once, so a consumer holding state for the gesture can release it"
    );
  });

  test("a drag returning to its origin still closes its gesture", async function (assert) {
    const state = new Harness();

    await render(
      <template>
        <div
          class="resize-edge"
          {{dResizeEdge
            axis="vertical"
            value=state.value
            min=240
            max=720
            onResizeStart=state.onResizeStart
            onResize=state.onResize
            onResizeEnd=state.onResizeEnd
          }}
        ></div>
      </template>
    );

    const edge = find(EDGE);
    stubPointerCapture(edge);

    await triggerEvent(edge, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientY: 300,
    });
    await triggerEvent(edge, "pointermove", {
      button: 0,
      pointerId: 1,
      clientY: 400,
    });
    await new Promise((resolve) => requestAnimationFrame(resolve));
    await triggerEvent(edge, "pointerup", { pointerId: 1, clientY: 300 });

    assert.strictEqual(state.resizeStarts, 1, "the gesture opened once");
    assert.strictEqual(
      state.resizeEnds.length,
      1,
      "and closed once, even though the pointer was released where it started"
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
    stubPointerCapture(edge);

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
    stubPointerCapture(edge);

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
    stubPointerCapture(verticalEdge);

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

  test("a writing direction change between gestures is picked up", async function (assert) {
    const state = new Harness();
    const container = new (class {
      @tracked dir = "ltr";
    })();

    await render(
      <template>
        <div dir={{container.dir}}>
          <div
            class="resize-edge"
            {{dResizeEdge
              value=state.value
              min=240
              max=720
              onResizeEnd=state.onResizeEnd
            }}
          ></div>
        </div>
      </template>
    );

    const edge = find(EDGE);
    stubPointerCapture(edge);

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
      state.resizeEnds,
      [340],
      "moving right grows a start-docked element under LTR"
    );

    container.dir = "rtl";
    await settled();

    // The direction is held for the length of a gesture, not for the length of
    // the modifier: a document that switches direction between two drags has to
    // be measured again rather than resized the old way.
    await triggerEvent(edge, "pointerdown", {
      button: 0,
      clientX: 300,
      pointerId: 2,
    });
    await triggerEvent(edge, "pointerup", {
      button: 0,
      clientX: 340,
      pointerId: 2,
    });

    assert.deepEqual(
      state.resizeEnds,
      [340, 260],
      "the same movement shrinks it once the document reads right-to-left"
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
    stubPointerCapture(edge);

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
    stubPointerCapture(edge);

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

  module("live argument reads", function () {
    test("a function value is read at the start of every pointer gesture", async function (assert) {
      const state = new Harness();
      let value = 500;
      let reads = 0;
      const readValue = () => {
        reads++;
        return value;
      };

      await render(
        <template>
          <div
            class="resize-edge"
            {{dResizeEdge
              value=readValue
              min=240
              max=720
              onResize=state.onResize
              onResizeEnd=state.onResizeEnd
            }}
          ></div>
        </template>
      );

      const edge = find(EDGE);
      stubPointerCapture(edge);
      await triggerEvent(edge, "pointerdown", {
        button: 0,
        clientX: 100,
        pointerId: 1,
      });
      await triggerEvent(edge, "pointerup", {
        button: 0,
        clientX: 150,
        pointerId: 1,
      });

      value = 400;
      await triggerEvent(edge, "pointerdown", {
        button: 0,
        clientX: 200,
        pointerId: 2,
      });
      await triggerEvent(edge, "pointerup", {
        button: 0,
        clientX: 180,
        pointerId: 2,
      });

      assert.strictEqual(reads, 2, "value is read once for each gesture");
      assert.deepEqual(
        state.resizeEnds,
        [550, 380],
        "each gesture starts from the value read when it begins"
      );
    });

    test("onResizeStart fires once and its return value is ignored", async function (assert) {
      const state = new Harness();
      let starts = 0;
      const onResizeStart = () => {
        starts++;
        return 500;
      };

      await render(
        <template>
          <div
            class="resize-edge"
            {{dResizeEdge
              value=state.value
              min=240
              max=720
              onResizeStart=onResizeStart
              onResize=state.onResize
              onResizeEnd=state.onResizeEnd
            }}
          ></div>
        </template>
      );

      const edge = find(EDGE);
      stubPointerCapture(edge);
      await triggerEvent(edge, "pointerdown", {
        button: 0,
        clientX: 100,
        pointerId: 1,
      });
      await triggerEvent(edge, "pointerup", {
        button: 0,
        clientX: 150,
        pointerId: 1,
      });

      assert.strictEqual(starts, 1, "the callback runs at gesture time");
      assert.deepEqual(
        state.resizeEnds,
        [350],
        "the gesture starts from value regardless of the callback return"
      );
    });

    test("mixed numeric and function bounds are read for every pointer clamp", async function (assert) {
      const state = new Harness();
      let max = 360;
      let maxReads = 0;
      const readMax = () => {
        maxReads++;
        return max;
      };

      await render(
        <template>
          <div
            class="resize-edge"
            {{dResizeEdge
              value=state.value
              min=240
              max=readMax
              onResize=state.onResize
              onResizeEnd=state.onResizeEnd
            }}
          ></div>
        </template>
      );

      const edge = find(EDGE);
      stubPointerCapture(edge);
      await triggerEvent(edge, "pointerdown", {
        button: 0,
        clientX: 300,
        pointerId: 1,
      });
      await triggerEvent(edge, "pointermove", {
        button: 0,
        clientX: 400,
        pointerId: 1,
      });
      await new Promise((resolve) => requestAnimationFrame(resolve));

      max = 340;
      await triggerEvent(edge, "pointerup", {
        button: 0,
        clientX: 420,
        pointerId: 1,
      });

      assert.strictEqual(maxReads, 2, "max is read for each pointer clamp");
      assert.deepEqual(
        state.resizes,
        [360, 340],
        "each pointer clamp uses the current maximum"
      );
      assert.deepEqual(
        state.resizeEnds,
        [340],
        "the gesture commits once at the current maximum"
      );
    });

    test("an interrupted resize keeps the size it was dragged to", async function (assert) {
      const state = new Harness();

      await render(
        <template>
          <div
            class="resize-edge"
            {{dResizeEdge
              value=state.value
              min=240
              max=720
              onResizeStart=state.onResizeStart
              onResize=state.onResize
              onResizeEnd=state.onResizeEnd
            }}
          ></div>
        </template>
      );

      const edge = find(EDGE);
      stubPointerCapture(edge);
      await triggerEvent(edge, "pointerdown", {
        button: 0,
        clientX: 300,
        pointerId: 1,
      });
      await triggerEvent(edge, "pointermove", {
        button: 0,
        clientX: 400,
        pointerId: 1,
      });
      await new Promise((resolve) => requestAnimationFrame(resolve));

      // The OS taking the pointer away mid-gesture. The modifier asks the gesture
      // engine to commit on cancel rather than revert, because snapping a pane
      // back to where it started would discard a resize the user watched happen.
      await triggerEvent(edge, "pointercancel", {
        button: 0,
        clientX: 400,
        pointerId: 1,
      });

      assert.strictEqual(state.resizeStarts, 1, "the gesture opened once");
      assert.deepEqual(
        state.resizes,
        [400, 400],
        "the drag reported the size it reached, and the commit reports it again as a release would"
      );
      assert.deepEqual(
        state.resizeEnds,
        [400],
        "and cancellation commits that size instead of reverting"
      );
    });

    test("coalesces the pointer moves sharing a frame into one report", async function (assert) {
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
      stubPointerCapture(edge);
      await triggerEvent(edge, "pointerdown", {
        button: 0,
        clientX: 300,
        pointerId: 1,
      });

      // Dispatched without awaiting in between: an await gives the browser room
      // to paint, which would put each move in its own frame and test the
      // opposite of the coalescing.
      for (const clientX of [320, 340, 360]) {
        edge.dispatchEvent(
          new PointerEvent("pointermove", {
            bubbles: true,
            button: 0,
            clientX,
            pointerId: 1,
          })
        );
      }
      await new Promise((resolve) => requestAnimationFrame(resolve));

      assert.deepEqual(
        state.resizes,
        [360],
        "the positions in between are dropped and only the latest is reported"
      );

      edge.dispatchEvent(
        new PointerEvent("pointermove", {
          bubbles: true,
          button: 0,
          clientX: 380,
          pointerId: 1,
        })
      );
      await new Promise((resolve) => requestAnimationFrame(resolve));

      assert.deepEqual(
        state.resizes,
        [360, 380],
        "the next frame reports again, so a frame is coalesced rather than the gesture reporting once"
      );
    });

    test("function value and bounds are read for every arrow key press", async function (assert) {
      const state = new Harness();
      let value = 300;
      let min = 240;
      let max = 720;
      const reads = { value: 0, min: 0, max: 0 };
      const readValue = () => {
        reads.value++;
        return value;
      };
      const readMin = () => {
        reads.min++;
        return min;
      };
      const readMax = () => {
        reads.max++;
        return max;
      };
      state.onResize = (size) => {
        state.resizes.push(size);
        value = size;
      };

      await render(
        <template>
          <div
            class="resize-edge"
            {{dResizeEdge
              value=readValue
              min=readMin
              max=readMax
              onResize=state.onResize
              onResizeEnd=state.onResizeEnd
            }}
          ></div>
        </template>
      );

      // Released between presses, so each is its own gesture. A held key is one
      // gesture and re-reads `value` only at its start — covered separately.
      await triggerKeyEvent(EDGE, "keydown", "ArrowRight");
      await triggerKeyEvent(EDGE, "keyup", "ArrowRight");

      max = 320;
      await triggerKeyEvent(EDGE, "keydown", "ArrowRight");
      await triggerKeyEvent(EDGE, "keyup", "ArrowRight");

      min = 310;
      await triggerKeyEvent(EDGE, "keydown", "ArrowLeft");
      await triggerKeyEvent(EDGE, "keyup", "ArrowLeft");

      assert.deepEqual(
        reads,
        { value: 3, min: 3, max: 3 },
        "value and both bounds are read for each discrete arrow key press"
      );
      assert.deepEqual(
        state.resizeEnds,
        [316, 320, 310],
        "arrow keys clamp against bounds that changed since render"
      );
    });
  });

  module("keyboard gesture", function () {
    test("a held arrow key steps once per repeat, not once per settled size", async function (assert) {
      const state = new Harness();
      // Deliberately frozen: a caller whose size is a live measurement reports a
      // box that is still animating toward the last size, so re-reading it on
      // every repeat would fold most of the step away.
      const stuckValue = () => 300;

      await render(
        <template>
          <div
            class="resize-edge"
            {{dResizeEdge
              value=stuckValue
              min=240
              max=720
              onResizeStart=state.onResizeStart
              onResize=state.onResize
              onResizeEnd=state.onResizeEnd
            }}
          ></div>
        </template>
      );

      await triggerKeyEvent(EDGE, "keydown", "ArrowRight");
      await triggerKeyEvent(EDGE, "keydown", "ArrowRight", { repeat: true });
      await triggerKeyEvent(EDGE, "keydown", "ArrowRight", { repeat: true });

      assert.deepEqual(
        state.resizes,
        [316, 332, 348],
        "each repeat steps from the size last reported, not from one that has not caught up"
      );

      await triggerKeyEvent(EDGE, "keyup", "ArrowRight");

      assert.strictEqual(
        state.resizeStarts,
        1,
        "the whole burst opens exactly one gesture"
      );
      assert.deepEqual(
        state.resizeEnds,
        [348],
        "and commits once, at the size it ended on"
      );
    });

    test("each discrete press is its own gesture", async function (assert) {
      const state = new Harness();

      await render(
        <template>
          <div
            class="resize-edge"
            {{dResizeEdge
              value=state.value
              min=240
              max=720
              onResizeStart=state.onResizeStart
              onResize=state.onResize
              onResizeEnd=state.onResizeEnd
            }}
          ></div>
        </template>
      );

      await triggerKeyEvent(EDGE, "keydown", "ArrowRight");
      await triggerKeyEvent(EDGE, "keyup", "ArrowRight");
      await triggerKeyEvent(EDGE, "keydown", "ArrowRight");
      await triggerKeyEvent(EDGE, "keyup", "ArrowRight");

      assert.strictEqual(state.resizeStarts, 2, "one gesture per press");
      assert.deepEqual(
        state.resizeEnds,
        [316, 332],
        "each press commits its own size"
      );
    });

    test("losing focus mid-burst ends the gesture", async function (assert) {
      const state = new Harness();

      await render(
        <template>
          <div
            class="resize-edge"
            tabindex="0"
            {{dResizeEdge
              value=state.value
              min=240
              max=720
              onResizeStart=state.onResizeStart
              onResize=state.onResize
              onResizeEnd=state.onResizeEnd
            }}
          ></div>
        </template>
      );

      await triggerKeyEvent(EDGE, "keydown", "ArrowRight");
      // The keyup lands on whatever took focus, so without this the gesture
      // would stay open forever and never commit.
      await triggerEvent(EDGE, "blur");

      assert.deepEqual(
        state.resizeEnds,
        [316],
        "the gesture commits the size it reached"
      );

      await triggerKeyEvent(EDGE, "keyup", "ArrowRight");

      assert.deepEqual(
        state.resizeEnds,
        [316],
        "and a keyup arriving afterwards does not commit a second time"
      );
    });

    test("every started gesture ends exactly once, whichever input began it", async function (assert) {
      const state = new Harness();

      await render(
        <template>
          <div
            class="resize-edge"
            tabindex="0"
            {{dResizeEdge
              value=state.value
              min=240
              max=720
              onResizeStart=state.onResizeStart
              onResize=state.onResize
              onResizeEnd=state.onResizeEnd
            }}
          ></div>
        </template>
      );

      const edge = find(EDGE);
      stubPointerCapture(edge);

      await triggerKeyEvent(EDGE, "keydown", "ArrowRight");
      // A pointer taking over mid-burst must close the keyboard gesture rather
      // than open a second one on top of it.
      await triggerEvent(edge, "pointerdown", {
        button: 0,
        pointerId: 1,
        clientX: 100,
        clientY: 0,
      });
      await triggerEvent(edge, "pointerup", {
        pointerId: 1,
        clientX: 140,
        clientY: 0,
      });
      await triggerKeyEvent(EDGE, "keyup", "ArrowRight");

      assert.strictEqual(
        state.resizeStarts,
        state.resizeEnds.length,
        "starts and ends stay balanced across both inputs"
      );
      assert.strictEqual(state.resizeStarts, 2, "one keyboard, one pointer");
    });
  });

  test("bodyClass marks the page for the length of the gesture", async function (assert) {
    await render(
      <template>
        <div
          class="dre-edge"
          {{dResizeEdge value=300 min=100 max=500 bodyClass="d-resizing-ns"}}
        ></div>
      </template>
    );

    const edge = find(".dre-edge");
    stubPointerCapture(edge);

    assert.dom(document.body).doesNotHaveClass("d-resizing-ns");

    await triggerEvent(edge, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientY: 400,
    });
    // A splitter's cursor has to outlive the pointer leaving the handle, and
    // whether that happens on its own is engine-dependent.
    assert.dom(document.body).hasClass("d-resizing-ns");

    await triggerEvent(edge, "pointerup", { pointerId: 1, clientY: 400 });
    assert.dom(document.body).doesNotHaveClass("d-resizing-ns");
  });
});
