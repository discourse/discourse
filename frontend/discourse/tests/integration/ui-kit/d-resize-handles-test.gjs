import { tracked } from "@glimmer/tracking";
import {
  clearRender,
  find,
  render,
  settled,
  triggerEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { stubPointerCapture } from "discourse/tests/helpers/ui-kit/pointer-gesture-helper";
import DResizeHandles from "discourse/ui-kit/d-resize-handles";

module("Integration | ui-kit | DResizeHandles", function (hooks) {
  setupRenderingTest(hooks);

  test("renders a handle per descriptor and passes its class through", async function (assert) {
    const handles = [
      { payload: "e", class: "handle-e" },
      { payload: "s", class: "handle-s" },
    ];

    await render(<template><DResizeHandles @handles={{handles}} /></template>);

    assert
      .dom("[data-resize-handle]")
      .exists({ count: 2 }, "renders one handle per descriptor");
    assert.dom(".handle-e").exists("forwards the descriptor's class");
    assert
      .dom("[data-resize-handle='e']")
      .exists("tags each handle with its payload");
  });

  test("@handleClass renders the 8-direction box with standalone modifiers", async function (assert) {
    await render(
      <template><DResizeHandles @handleClass="my-block__handle" /></template>
    );

    assert
      .dom("[data-resize-handle]")
      .exists({ count: 8 }, "renders the eight compass handles");
    assert
      .dom("[data-resize-handle='ne']")
      .hasClass("my-block__handle", "applies the base class")
      .hasClass("--ne", "applies the standalone direction modifier")
      .doesNotHaveClass(
        "my-block__handle--ne",
        "does not generate a suffixed BEM modifier"
      );
    assert
      .dom("[data-resize-handle='w']")
      .hasClass("--w", "each direction gets its standalone modifier");
  });

  test("naming @handles opts out of the box even when it resolves to nothing", async function (assert) {
    // `Payload` is inferred from `@handles`, so a consumer whose descriptors are
    // momentarily undefined has callbacks typed for its own payload. Falling
    // back to the box here would hand those callbacks compass strings instead,
    // type-checked and wrong.
    const noHandles = undefined;

    await render(
      <template>
        <DResizeHandles
          @handleClass="my-block__handle"
          @handles={{noHandles}}
        />
      </template>
    );

    assert
      .dom("[data-resize-handle]")
      .doesNotExist("renders no handles rather than eight compass ones");
  });

  test("@directions renders exactly the subset it names", async function (assert) {
    const directions = ["n", "se"];

    await render(
      <template>
        <DResizeHandles
          @handleClass="my-block__handle"
          @directions={{directions}}
        />
      </template>
    );

    assert
      .dom("[data-resize-handle]")
      .exists({ count: 2 }, "renders only the named directions");
    assert.dom("[data-resize-handle='n']").exists("renders the north handle");
    assert
      .dom("[data-resize-handle='se']")
      .exists("renders the south-east handle");
    assert
      .dom("[data-resize-handle='e']")
      .doesNotExist("and none of the six it did not name");
  });

  test("@draggingClass marks the handle being dragged, and only it", async function (assert) {
    await render(
      <template>
        <DResizeHandles
          @handleClass="my-block__handle"
          @draggingClass="--dragging"
        />
      </template>
    );

    const east = stubPointerCapture("[data-resize-handle='e']").element;
    await triggerEvent(east, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 0,
      clientY: 0,
    });

    assert
      .dom("[data-resize-handle='e']")
      .hasClass("--dragging", "the pressed handle carries the class");
    assert
      .dom("[data-resize-handle='w']")
      .doesNotHaveClass("--dragging", "its siblings do not");

    await triggerEvent(east, "pointerup", {
      pointerId: 1,
      clientX: 0,
      clientY: 0,
    });

    assert
      .dom("[data-resize-handle='e']")
      .doesNotHaveClass("--dragging", "and it is dropped on release");
  });

  test("a descriptor's plain style string is applied without a dynamic-style warning", async function (assert) {
    const warn = sinon.stub(console, "warn");
    const handles = [
      { payload: "gutter", class: "handle-gutter", style: "grid-column: 3" },
    ];

    await render(<template><DResizeHandles @handles={{handles}} /></template>);

    assert
      .dom(".handle-gutter")
      .hasAttribute("style", "grid-column: 3", "the style reaches the element");
    // The wrap exists precisely so a consumer can pass a plain string here. If
    // it stopped wrapping, the style would still land and only this would notice.
    assert.false(
      warn.getCalls().some((call) => String(call.args[0]).includes("style")),
      "and does so without tripping the dynamic-style warning"
    );
  });

  test("@measure reports the resized box's bounds, not the handle's", async function (assert) {
    let reported = null;
    const onResizeStart = (payload, info) => (reported = info.measuredRect);
    const findBox = (handle) =>
      handle.closest(".fixture")?.querySelector(".box");

    await render(
      <template>
        <div class="fixture">
          <div class="box" style="width: 220px; height: 90px"></div>
          <DResizeHandles
            @handleClass="my-block__handle"
            @measure={{findBox}}
            @onResizeStart={{onResizeStart}}
          />
        </div>
      </template>
    );

    const east = stubPointerCapture("[data-resize-handle='e']").element;
    await triggerEvent(east, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 0,
      clientY: 0,
    });

    const box = find(".box").getBoundingClientRect();
    assert.strictEqual(
      reported?.width,
      box.width,
      "reports the measured box's width"
    );
    assert.strictEqual(
      reported?.height,
      box.height,
      "and its height, which a 6px handle's own bounds could never give"
    );
  });

  test("@measure is absent by default rather than reporting something arbitrary", async function (assert) {
    let reported = "untouched";
    const onResizeStart = (payload, info) => (reported = info.measuredRect);

    await render(
      <template>
        <DResizeHandles
          @handleClass="my-block__handle"
          @onResizeStart={{onResizeStart}}
        />
      </template>
    );

    const east = stubPointerCapture("[data-resize-handle='e']").element;
    await triggerEvent(east, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 0,
      clientY: 0,
    });

    assert.strictEqual(reported, null, "nothing to measure, nothing reported");
  });

  test("@measure accepts the element itself, not only a function", async function (assert) {
    let reported = null;
    const onResizeStart = (payload, info) => (reported = info.measuredRect);
    const body = document.body;

    await render(
      <template>
        <DResizeHandles
          @handleClass="my-block__handle"
          @measure={{body}}
          @onResizeStart={{onResizeStart}}
        />
      </template>
    );

    const east = stubPointerCapture("[data-resize-handle='e']").element;
    await triggerEvent(east, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 0,
      clientY: 0,
    });

    assert.strictEqual(
      reported?.width,
      document.body.getBoundingClientRect().width,
      "an element target is measured directly"
    );
  });

  test("@measure hands back the element alongside its bounds", async function (assert) {
    let reported = null;
    const onResizeStart = (payload, info) => (reported = info.measured);
    const findBox = (handle) =>
      handle.closest(".fixture")?.querySelector(".box");

    await render(
      <template>
        <div class="fixture">
          <div class="box" style="width: 220px; height: 90px"></div>
          <DResizeHandles
            @handleClass="my-block__handle"
            @measure={{findBox}}
            @onResizeStart={{onResizeStart}}
          />
        </div>
      </template>
    );

    const east = stubPointerCapture("[data-resize-handle='e']").element;
    await triggerEvent(east, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 0,
      clientY: 0,
    });

    assert.strictEqual(
      reported,
      find(".box"),
      "so a consumer painting a preview on it need not resolve it again"
    );
  });

  test("@measure re-reads the box when it moves under a held gesture", async function (assert) {
    const rects = [];
    const onResize = (payload, info) => rects.push(info.measuredRect);
    const findBox = (handle) =>
      handle.closest(".fixture")?.querySelector(".box");

    await render(
      <template>
        <div class="fixture">
          <div class="box" style="width: 220px; height: 90px"></div>
          <DResizeHandles
            @handleClass="my-block__handle"
            @measure={{findBox}}
            @onResize={{onResize}}
          />
        </div>
      </template>
    );

    const east = stubPointerCapture("[data-resize-handle='e']").element;
    await triggerEvent(east, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 0,
      clientY: 0,
    });
    await triggerEvent(east, "pointermove", {
      pointerId: 1,
      clientX: 10,
      clientY: 0,
    });
    const before = rects.at(-1).left;

    // The box moves without changing size, as a scroll would move it. Bounds
    // frozen at press-time would land the pointer in the wrong place for the
    // rest of the gesture.
    find(".box").style.marginLeft = "40px";
    window.dispatchEvent(new Event("scroll"));
    await settled();

    // Read rather than computed: the test container is scaled, so the viewport
    // delta is not the margin that produced it.
    const moved = find(".box").getBoundingClientRect().left;
    assert.notStrictEqual(moved, before, "control: the box really did move");

    await triggerEvent(east, "pointermove", {
      pointerId: 1,
      clientX: 20,
      clientY: 0,
    });

    assert.strictEqual(
      rects.at(-1).left,
      moved,
      "the reported bounds follow the box"
    );
  });

  test("the reflow listeners are released when the gesture ends", async function (assert) {
    const findBox = (handle) =>
      handle.closest(".fixture")?.querySelector(".box");

    await render(
      <template>
        <div class="fixture">
          <div class="box" style="width: 220px; height: 90px"></div>
          <DResizeHandles
            @handleClass="my-block__handle"
            @measure={{findBox}}
          />
        </div>
      </template>
    );

    const east = stubPointerCapture("[data-resize-handle='e']").element;
    await triggerEvent(east, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 0,
      clientY: 0,
    });

    // Spied only from here, so the release's own detach is the one observed.
    const removeSpy = sinon.spy(window, "removeEventListener");
    await triggerEvent(east, "pointerup", {
      pointerId: 1,
      clientX: 0,
      clientY: 0,
    });

    assert.true(
      removeSpy
        .getCalls()
        .some((call) => call.args[0] === "scroll" && call.args[2] === true),
      "the capture-phase scroll listener does not outlive the gesture"
    );
  });

  test("a refused press releases what it reserved", async function (assert) {
    const onResizeStart = () => false;
    const findBox = (handle) =>
      handle.closest(".fixture")?.querySelector(".box");

    await render(
      <template>
        <div class="fixture">
          <div class="box" style="width: 220px; height: 90px"></div>
          <DResizeHandles
            @handleClass="my-block__handle"
            @measure={{findBox}}
            @onResizeStart={{onResizeStart}}
          />
        </div>
      </template>
    );

    const east = stubPointerCapture("[data-resize-handle='e']").element;
    const removeSpy = sinon.spy(window, "removeEventListener");
    await triggerEvent(east, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 0,
      clientY: 0,
    });

    // A vetoed press starts no gesture, so no terminal callback will ever
    // arrive to clean up after it. Observed through the listeners rather than
    // the session map, because a later press on the same pointer id would
    // overwrite a stranded session and hide the leak.
    assert.true(
      removeSpy
        .getCalls()
        .some((call) => call.args[0] === "scroll" && call.args[2] === true),
      "the refused press leaves no listener behind"
    );
  });

  test("a throwing commit callback still releases the gesture", async function (assert) {
    const onResizeEnd = () => {
      throw new Error("consumer failure");
    };
    const findBox = (handle) =>
      handle.closest(".fixture")?.querySelector(".box");

    await render(
      <template>
        <div class="fixture">
          <div class="box" style="width: 220px; height: 90px"></div>
          <DResizeHandles
            @handleClass="my-block__handle"
            @measure={{findBox}}
            @onResizeEnd={{onResizeEnd}}
          />
        </div>
      </template>
    );

    const east = stubPointerCapture("[data-resize-handle='e']").element;
    await triggerEvent(east, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 0,
      clientY: 0,
    });

    const removeSpy = sinon.spy(window, "removeEventListener");
    // The throw is the consumer's bug and is rethrown, so it surfaces as an
    // uncaught error rather than a rejected promise. Swallowed here so the
    // assertion below is about cleanup rather than about the throw.
    const priorOnError = window.onerror;
    window.onerror = (...args) =>
      args[4]?.message === "consumer failure" || priorOnError?.(...args);
    try {
      await triggerEvent(east, "pointerup", {
        pointerId: 1,
        clientX: 0,
        clientY: 0,
      });
    } finally {
      window.onerror = priorOnError;
    }

    assert.true(
      removeSpy
        .getCalls()
        .some((call) => call.args[0] === "scroll" && call.args[2] === true),
      "a consumer that throws cannot strand the gesture's listeners"
    );
  });

  test("the reflow listeners go once nothing measured is left, not once nothing is left", async function (assert) {
    // Only the east handle resolves a box, so the two concurrent gestures differ
    // in whether they have anything to re-measure.
    const measureEastOnly = (handle) =>
      handle.dataset.resizeHandle === "e"
        ? handle.closest(".fixture")?.querySelector(".box")
        : null;

    await render(
      <template>
        <div class="fixture">
          <div class="box" style="width: 220px; height: 90px"></div>
          <DResizeHandles
            @handleClass="my-block__handle"
            @measure={{measureEastOnly}}
          />
        </div>
      </template>
    );

    const east = stubPointerCapture("[data-resize-handle='e']").element;
    const south = stubPointerCapture("[data-resize-handle='s']").element;
    await triggerEvent(east, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 0,
      clientY: 0,
    });
    await triggerEvent(south, "pointerdown", {
      button: 0,
      pointerId: 2,
      clientX: 0,
      clientY: 0,
    });

    const removeSpy = sinon.spy(window, "removeEventListener");
    // Waiting for the session map to empty would keep a document-wide listener
    // alive for the rest of a gesture that has nothing for it to do.
    await triggerEvent(east, "pointerup", {
      pointerId: 1,
      clientX: 0,
      clientY: 0,
    });

    assert.true(
      removeSpy
        .getCalls()
        .some((call) => call.args[0] === "scroll" && call.args[2] === true),
      "the listener goes with the last gesture that had a box"
    );
  });

  test("a released gesture does not stop the one still held from re-reading", async function (assert) {
    const rects = [];
    const onResize = (payload, info) => rects.push(info.measuredRect);
    const findBox = (handle) =>
      handle.closest(".fixture")?.querySelector(".box");

    await render(
      <template>
        <div class="fixture">
          <div class="box" style="width: 220px; height: 90px"></div>
          <DResizeHandles
            @handleClass="my-block__handle"
            @measure={{findBox}}
            @onResize={{onResize}}
          />
        </div>
      </template>
    );

    const east = stubPointerCapture("[data-resize-handle='e']").element;
    const south = stubPointerCapture("[data-resize-handle='s']").element;
    await triggerEvent(east, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 0,
      clientY: 0,
    });
    await triggerEvent(south, "pointerdown", {
      button: 0,
      pointerId: 2,
      clientX: 0,
      clientY: 0,
    });
    await triggerEvent(east, "pointerup", {
      pointerId: 1,
      clientX: 0,
      clientY: 0,
    });
    await triggerEvent(south, "pointermove", {
      pointerId: 2,
      clientX: 0,
      clientY: 10,
    });
    const before = rects.at(-1).left;

    find(".box").style.marginLeft = "40px";
    window.dispatchEvent(new Event("scroll"));
    await settled();

    const moved = find(".box").getBoundingClientRect().left;
    assert.notStrictEqual(moved, before, "control: the box really did move");

    await triggerEvent(south, "pointermove", {
      pointerId: 2,
      clientX: 0,
      clientY: 20,
    });

    // Detaching on every release would leave this gesture reporting press-time
    // bounds for the rest of its life, which is the stale hit-test the live
    // rect exists to prevent.
    assert.strictEqual(
      rects.at(-1).left,
      moved,
      "the surviving gesture keeps its bounds up to date"
    );
  });

  test("@onResizeCancel fires when the gesture is cancelled rather than released", async function (assert) {
    const events = [];
    const onResizeEnd = (payload) => events.push(`end:${payload}`);
    const onResizeCancel = (payload) => events.push(`cancel:${payload}`);

    await render(
      <template>
        <DResizeHandles
          @handleClass="my-block__handle"
          @onResizeEnd={{onResizeEnd}}
          @onResizeCancel={{onResizeCancel}}
        />
      </template>
    );

    const east = stubPointerCapture("[data-resize-handle='e']").element;
    await triggerEvent(east, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 0,
      clientY: 0,
    });
    await triggerEvent(east, "pointercancel", {
      pointerId: 1,
      clientX: 0,
      clientY: 0,
    });

    assert.deepEqual(
      events,
      ["cancel:e"],
      "a cancel reaches the cancel callback and not the end callback"
    );
  });

  test("handles are hidden from assistive technology", async function (assert) {
    await render(
      <template><DResizeHandles @handleClass="my-block__handle" /></template>
    );

    // They are pointer affordances with no accessible name and no tab stop, so
    // exposing them would announce eight nameless nodes per box. Keyboard
    // operation is the consumer's job, on the resized object itself.
    assert
      .dom("[data-resize-handle='ne']")
      .hasAttribute("aria-hidden", "true", "each handle is hidden from AT");
  });

  test("explicit @handles take precedence over @handleClass", async function (assert) {
    const handles = [{ payload: "only", class: "explicit-handle" }];

    await render(
      <template>
        <DResizeHandles @handleClass="my-block__handle" @handles={{handles}} />
      </template>
    );

    assert
      .dom("[data-resize-handle]")
      .exists({ count: 1 }, "the escape hatch wins over the box default");
    assert.dom(".explicit-handle").exists();
  });

  test("dispatches start / resize / end with the payload and the pointer delta", async function (assert) {
    const handles = [{ payload: "e", class: "handle-e" }];
    const events = [];
    const onResizeStart = (payload) => events.push(`start:${payload}`);
    const onResize = (payload, info) =>
      events.push(`resize:${payload}:${info.delta.x},${info.delta.y}`);
    const onResizeEnd = (payload) => events.push(`end:${payload}`);

    await render(
      <template>
        <DResizeHandles
          @handles={{handles}}
          @onResizeStart={{onResizeStart}}
          @onResize={{onResize}}
          @onResizeEnd={{onResizeEnd}}
        />
      </template>
    );

    stubPointerCapture(".handle-e");
    await triggerEvent(".handle-e", "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 100,
      clientY: 50,
    });
    await triggerEvent(".handle-e", "pointermove", {
      pointerId: 1,
      clientX: 130,
      clientY: 60,
    });
    await triggerEvent(".handle-e", "pointerup", {
      pointerId: 1,
      clientX: 130,
      clientY: 60,
    });

    assert.deepEqual(
      events,
      ["start:e", "resize:e:30,10", "end:e"],
      "reports the handle payload and the origin→current delta"
    );
  });

  test("a vetoed press starts no gesture and does not spoil the next one", async function (assert) {
    const handles = [{ payload: "e", class: "handle-e" }];
    const events = [];
    const state = { veto: true };
    const onResizeStart = () => (state.veto ? false : undefined);
    const onResize = (payload, info) =>
      events.push(`resize:${payload}:${info.delta.x}`);
    const onResizeEnd = (payload) => events.push(`end:${payload}`);

    await render(
      <template>
        <DResizeHandles
          @handles={{handles}}
          @onResizeStart={{onResizeStart}}
          @onResize={{onResize}}
          @onResizeEnd={{onResizeEnd}}
        />
      </template>
    );

    stubPointerCapture(".handle-e");
    await triggerEvent(".handle-e", "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 100,
      clientY: 50,
    });
    await triggerEvent(".handle-e", "pointermove", {
      pointerId: 1,
      clientX: 130,
      clientY: 50,
    });
    await triggerEvent(".handle-e", "pointerup", {
      pointerId: 1,
      clientX: 130,
      clientY: 50,
    });

    assert.deepEqual(
      events,
      [],
      "returning false from the start callback refuses the drag outright"
    );

    // The same pointer presses again, elsewhere, and is accepted this time.
    // Each press records where it began under the pointer's own id, so this
    // measures from 200 rather than carrying anything over from the press that
    // was refused.
    state.veto = false;
    await triggerEvent(".handle-e", "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 200,
      clientY: 50,
    });
    await triggerEvent(".handle-e", "pointermove", {
      pointerId: 1,
      clientX: 230,
      clientY: 50,
    });
    await triggerEvent(".handle-e", "pointerup", {
      pointerId: 1,
      clientX: 230,
      clientY: 50,
    });

    assert.deepEqual(
      events,
      ["resize:e:30", "end:e"],
      "the accepted press measures from where it began"
    );
  });

  test("the reported payload follows a descriptor list that changes mid-drag", async function (assert) {
    const state = new (class {
      @tracked handles = [{ payload: "first", class: "handle-x" }];
    })();
    const events = [];
    const onResize = (payload) => events.push(payload);

    await render(
      <template>
        <DResizeHandles @handles={{state.handles}} @onResize={{onResize}} />
      </template>
    );

    stubPointerCapture(".handle-x");
    await triggerEvent(".handle-x", "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 100,
      clientY: 50,
    });
    await triggerEvent(".handle-x", "pointermove", {
      pointerId: 1,
      clientX: 120,
      clientY: 50,
    });

    state.handles = [{ payload: "second", class: "handle-x" }];
    await settled();

    await triggerEvent(".handle-x", "pointermove", {
      pointerId: 1,
      clientX: 140,
      clientY: 50,
    });

    // The payload comes from the callback's own binding rather than a snapshot
    // taken at the press, so it always names the descriptor the handler is
    // currently bound to. Pinned here because the per-pointer session holds the
    // press coordinates and could plausibly be made to hold the payload too,
    // which would freeze it at what was pressed.
    assert.deepEqual(
      events,
      ["first", "second"],
      "the payload tracks the rebound descriptor"
    );

    await triggerEvent(".handle-x", "pointerup", {
      pointerId: 1,
      clientX: 140,
      clientY: 50,
    });
  });

  test("two handles dragged at once keep their own origins", async function (assert) {
    const handles = [
      { payload: "nw", class: "handle-nw" },
      { payload: "se", class: "handle-se" },
    ];
    const events = [];
    const onResize = (payload, info) =>
      events.push(`${payload}:${info.delta.x},${info.delta.y}`);

    await render(
      <template>
        <DResizeHandles @handles={{handles}} @onResize={{onResize}} />
      </template>
    );

    stubPointerCapture(".handle-nw");
    stubPointerCapture(".handle-se");

    // Two fingers on two handles of the same box. Each gesture has its own
    // pointer id, so the engine keeps both live, and one must not overwrite the
    // other's origin.
    await triggerEvent(".handle-nw", "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 100,
      clientY: 100,
    });
    await triggerEvent(".handle-se", "pointerdown", {
      button: 0,
      pointerId: 2,
      clientX: 400,
      clientY: 400,
    });

    await triggerEvent(".handle-nw", "pointermove", {
      pointerId: 1,
      clientX: 120,
      clientY: 120,
    });
    await triggerEvent(".handle-se", "pointermove", {
      pointerId: 2,
      clientX: 430,
      clientY: 430,
    });

    assert.deepEqual(
      events,
      ["nw:20,20", "se:30,30"],
      "each handle reports the delta from its own press, not from the other's"
    );

    await triggerEvent(".handle-nw", "pointerup", {
      pointerId: 1,
      clientX: 120,
      clientY: 120,
    });
    await triggerEvent(".handle-se", "pointerup", {
      pointerId: 2,
      clientX: 430,
      clientY: 430,
    });
  });

  test("@stopPropagation keeps the press from reaching an ancestor", async function (assert) {
    const handles = [{ payload: "e", class: "handle-e" }];
    const ancestorPresses = [];

    await render(
      <template>
        <div class="ancestor">
          <DResizeHandles @handles={{handles}} @stopPropagation={{true}} />
        </div>
      </template>
    );

    find(".ancestor").addEventListener("pointerdown", () =>
      ancestorPresses.push("ancestor")
    );
    stubPointerCapture(".handle-e");
    await triggerEvent(".handle-e", "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 0,
      clientY: 0,
    });

    assert.deepEqual(
      ancestorPresses,
      [],
      "an isolated handle does not let an enclosing gesture claim the pointer"
    );
  });

  test("a press reaches an ancestor by default", async function (assert) {
    const handles = [{ payload: "e", class: "handle-e" }];
    const ancestorPresses = [];

    await render(
      <template>
        <div class="ancestor">
          <DResizeHandles @handles={{handles}} />
        </div>
      </template>
    );

    find(".ancestor").addEventListener("pointerdown", (event) =>
      ancestorPresses.push(event.defaultPrevented ? "accepted" : "ancestor")
    );
    stubPointerCapture(".handle-e");
    await triggerEvent(".handle-e", "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 0,
      clientY: 0,
    });

    // Read through `defaultPrevented`, which only an accepted press sets. A press
    // that started no gesture bubbles too, so the ancestor seeing it proves
    // nothing on its own.
    assert.deepEqual(
      ancestorPresses,
      ["accepted"],
      "suppression stays opt-in, so document-level listeners still see a press that did start a gesture"
    );
  });

  test("@threshold suppresses jitter before the first resize", async function (assert) {
    const handles = [{ payload: "e", class: "handle-e" }];
    const events = [];
    const onResize = (payload, info) => events.push(`resize:${info.delta.x}`);
    const onResizeEnd = () => events.push("end");

    await render(
      <template>
        <DResizeHandles
          @handles={{handles}}
          @threshold={{10}}
          @onResize={{onResize}}
          @onResizeEnd={{onResizeEnd}}
        />
      </template>
    );

    stubPointerCapture(".handle-e");
    await triggerEvent(".handle-e", "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 0,
      clientY: 0,
    });
    await triggerEvent(".handle-e", "pointermove", {
      pointerId: 1,
      clientX: 4,
      clientY: 0,
    });

    assert.deepEqual(
      events,
      [],
      "movement inside the threshold reports nothing"
    );

    await triggerEvent(".handle-e", "pointermove", {
      pointerId: 1,
      clientX: 12,
      clientY: 0,
    });
    await triggerEvent(".handle-e", "pointerup", {
      pointerId: 1,
      clientX: 12,
      clientY: 0,
    });

    assert.deepEqual(
      events,
      ["resize:12", "end"],
      "past the threshold the full delta from the press origin is reported"
    );
  });

  test("a gesture still held at teardown is cancelled once", async function (assert) {
    const handles = [{ payload: "e", class: "handle-e" }];
    const events = [];
    const onResizeCancel = (payload) => events.push(`cancel:${payload}`);
    const onResizeEnd = (payload) => events.push(`end:${payload}`);

    await render(
      <template>
        <DResizeHandles
          @handles={{handles}}
          @onResizeCancel={{onResizeCancel}}
          @onResizeEnd={{onResizeEnd}}
        />
      </template>
    );

    stubPointerCapture(".handle-e");
    await triggerEvent(".handle-e", "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 0,
      clientY: 0,
    });
    await triggerEvent(".handle-e", "pointermove", {
      pointerId: 1,
      clientX: 30,
      clientY: 0,
    });

    await clearRender();

    // The engine reports nothing when the element goes, so whatever the consumer
    // opened at the press would stay open with no callback left to close it.
    assert.deepEqual(
      events,
      ["cancel:e"],
      "the held gesture is cancelled exactly once on the way out"
    );
  });

  test("a gesture that already ended is not cancelled again at teardown", async function (assert) {
    const handles = [{ payload: "e", class: "handle-e" }];
    const events = [];
    const onResizeCancel = (payload) => events.push(`cancel:${payload}`);
    const onResizeEnd = (payload) => events.push(`end:${payload}`);

    await render(
      <template>
        <DResizeHandles
          @handles={{handles}}
          @onResizeCancel={{onResizeCancel}}
          @onResizeEnd={{onResizeEnd}}
        />
      </template>
    );

    stubPointerCapture(".handle-e");
    await triggerEvent(".handle-e", "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 0,
      clientY: 0,
    });
    await triggerEvent(".handle-e", "pointerup", {
      pointerId: 1,
      clientX: 0,
      clientY: 0,
    });

    assert.deepEqual(events, ["end:e"], "the release reported once");

    await clearRender();

    assert.deepEqual(
      events,
      ["end:e"],
      "and teardown has nothing left to close"
    );
  });

  test("@cancelCommits routes a gesture held at teardown to the commit callback", async function (assert) {
    const handles = [{ payload: "e", class: "handle-e" }];
    const events = [];
    const onResizeCancel = (payload) => events.push(`cancel:${payload}`);
    const onResizeEnd = (payload) => events.push(`end:${payload}`);

    await render(
      <template>
        <DResizeHandles
          @handles={{handles}}
          @cancelCommits={{true}}
          @onResizeCancel={{onResizeCancel}}
          @onResizeEnd={{onResizeEnd}}
        />
      </template>
    );

    stubPointerCapture(".handle-e");
    await triggerEvent(".handle-e", "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 0,
      clientY: 0,
    });
    await triggerEvent(".handle-e", "pointermove", {
      pointerId: 1,
      clientX: 30,
      clientY: 0,
    });

    await clearRender();

    // Teardown is an end the pointer was never released for, so it reports the
    // way every other such end does rather than inventing a third route.
    assert.deepEqual(
      events,
      ["end:e"],
      "the held gesture commits instead of cancelling"
    );
  });

  test("a throwing consumer cannot abort the teardown of its siblings", async function (assert) {
    const handles = [{ payload: "e", class: "handle-e" }];
    const onResizeCancel = () => {
      throw new Error("consumer blew up on teardown");
    };
    const errors = sinon.stub(console, "error");

    await render(
      <template>
        <DResizeHandles
          @handles={{handles}}
          @onResizeCancel={{onResizeCancel}}
        />
      </template>
    );

    stubPointerCapture(".handle-e");
    await triggerEvent(".handle-e", "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 0,
      clientY: 0,
    });

    // A destructor throws into the flush tearing down every sibling component,
    // and would take their cleanup with it.
    await clearRender();

    assert.true(
      errors.calledOnce,
      "the consumer's exception is reported rather than escaping the flush"
    );
  });
});
