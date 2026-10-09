import { tracked } from "@glimmer/tracking";
import { trustHTML } from "@ember/template";
import {
  clearRender,
  find,
  render,
  resetOnerror,
  settled,
  setupOnerror,
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
      { payload: "e", key: "e", class: "handle-e" },
      { payload: "s", key: "s", class: "handle-s" },
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
          @directions={{directions}}
          @handleClass="my-block__handle"
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
          @draggingClass="--dragging"
          @handleClass="my-block__handle"
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

  test("a descriptor's trusted style is applied without a dynamic-style warning", async function (assert) {
    const warn = sinon.stub(console, "warn");
    const handles = [
      {
        payload: "gutter",
        key: "gutter",
        class: "handle-gutter",
        style: trustHTML("grid-column: 3"),
      },
    ];

    await render(<template><DResizeHandles @handles={{handles}} /></template>);

    assert
      .dom(".handle-gutter")
      .hasAttribute("style", "grid-column: 3", "the style reaches the element");
    // The component passes the trusted value straight through. If it re-wrapped
    // or stringified it, the style would still land and only this would catch it.
    assert.false(
      warn.getCalls().some((call) => String(call.args[0]).includes("style")),
      "and does so without tripping the dynamic-style warning"
    );
  });

  test("a descriptor's plain style string is refused rather than trusted", async function (assert) {
    const consoleError = sinon.stub(console, "error");
    const handles = [
      {
        payload: "gutter",
        key: "gutter",
        class: "handle-gutter",
        style: "grid-column: 3",
      },
    ];
    let errors = 0;

    // Only the caller knows whether it interpolated anything unsafe, so the
    // component will not trust the string on its behalf.
    setupOnerror((error) => {
      assert.true(
        error.message.includes("trustHTML"),
        "the assertion names the call the consumer has to make"
      );
      errors++;
    });

    await render(<template><DResizeHandles @handles={{handles}} /></template>);

    assert.strictEqual(errors, 1, "the untrusted style is reported once");

    resetOnerror();
    consoleError.restore();
  });

  test("a descriptor with no key is refused rather than keyed by position", async function (assert) {
    const consoleError = sinon.stub(console, "error");
    const handles = [{ payload: "gutter", class: "handle-gutter" }];
    let errors = 0;

    // Glimmer would fall back to position here, which is the bug keys exist to
    // remove, and it would do it without saying anything.
    setupOnerror((error) => {
      assert.true(
        error.message.includes("every handle descriptor needs"),
        "the assertion names what is missing"
      );
      errors++;
    });

    await render(<template><DResizeHandles @handles={{handles}} /></template>);

    assert.strictEqual(errors, 1, "the missing key is reported once");

    resetOnerror();
    consoleError.restore();
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
    // the gesture map, because a later press on the same pointer id would
    // overwrite a stranded entry and hide the leak.
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

  test("a second press is refused while a gesture is held", async function (assert) {
    const handles = [
      { payload: "nw", key: "nw", class: "handle-nw" },
      { payload: "se", key: "se", class: "handle-se" },
    ];
    const events = [];
    const onResizeStart = (payload) => events.push(`start:${payload}`);
    const onResize = (payload, info) =>
      events.push(`resize:${payload}:${info.delta.x}`);
    const onResizeEnd = (payload) => events.push(`end:${payload}`);

    await render(
      <template>
        <DResizeHandles
          @handles={{handles}}
          @onResize={{onResize}}
          @onResizeEnd={{onResizeEnd}}
          @onResizeStart={{onResizeStart}}
        />
      </template>
    );

    stubPointerCapture(".handle-nw");
    stubPointerCapture(".handle-se");

    await triggerEvent(".handle-nw", "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 100,
      clientY: 100,
    });
    // A second finger on another handle of the same box. One gesture at a time,
    // so this press never starts.
    await triggerEvent(".handle-se", "pointerdown", {
      button: 0,
      pointerId: 2,
      clientX: 400,
      clientY: 400,
    });
    await triggerEvent(".handle-se", "pointermove", {
      pointerId: 2,
      clientX: 430,
      clientY: 430,
    });
    await triggerEvent(".handle-nw", "pointermove", {
      pointerId: 1,
      clientX: 120,
      clientY: 100,
    });
    await triggerEvent(".handle-nw", "pointerup", {
      pointerId: 1,
      clientX: 120,
      clientY: 100,
    });

    assert.deepEqual(
      events,
      ["start:nw", "resize:nw:20", "end:nw"],
      "the refused press reports nothing and the held gesture is untouched"
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
          @onResizeCancel={{onResizeCancel}}
          @onResizeEnd={{onResizeEnd}}
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
    const handles = [
      { payload: "only", key: "only", class: "explicit-handle" },
    ];

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
    const handles = [{ payload: "e", key: "e", class: "handle-e" }];
    const events = [];
    const onResizeStart = (payload) => events.push(`start:${payload}`);
    const onResize = (payload, info) =>
      events.push(`resize:${payload}:${info.delta.x},${info.delta.y}`);
    const onResizeEnd = (payload) => events.push(`end:${payload}`);

    await render(
      <template>
        <DResizeHandles
          @handles={{handles}}
          @onResize={{onResize}}
          @onResizeEnd={{onResizeEnd}}
          @onResizeStart={{onResizeStart}}
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
    const handles = [{ payload: "e", key: "e", class: "handle-e" }];
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
          @onResize={{onResize}}
          @onResizeEnd={{onResizeEnd}}
          @onResizeStart={{onResizeStart}}
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

  test("replacing a held descriptor ends its gesture rather than rebinding it", async function (assert) {
    const state = new (class {
      @tracked
      handles = [{ payload: "first", key: "first", class: "handle-x" }];
    })();
    const events = [];
    const onResize = (payload) => events.push(`resize:${payload}`);
    const onResizeCancel = (payload) => events.push(`cancel:${payload}`);

    await render(
      <template>
        <DResizeHandles
          @handles={{state.handles}}
          @onResize={{onResize}}
          @onResizeCancel={{onResizeCancel}}
        />
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

    state.handles = [{ payload: "second", key: "second", class: "handle-x" }];
    await settled();

    await triggerEvent(".handle-x", "pointermove", {
      pointerId: 1,
      clientX: 140,
      clientY: 50,
    });

    // The handle the user grabbed is gone, so the gesture ends on the payload it
    // started with. Reporting the descriptor that replaced it would commit
    // something the user never touched.
    assert.deepEqual(
      events,
      ["resize:first", "cancel:first"],
      "the gesture ends rather than retargeting the replacement"
    );

    await triggerEvent(".handle-x", "pointerup", {
      pointerId: 1,
      clientX: 140,
      clientY: 50,
    });

    assert.deepEqual(
      events,
      ["resize:first", "cancel:first"],
      "and the release of a gesture already ended reports nothing further"
    );
  });

  test("removing the held handle ends its gesture and leaves its neighbours in place", async function (assert) {
    const state = new (class {
      @tracked
      handles = [
        { payload: "a", key: "a", class: "handle-a" },
        { payload: "b", key: "b", class: "handle-b" },
        { payload: "c", key: "c", class: "handle-c" },
      ];
    })();
    const events = [];
    const onResize = (payload) => events.push(`resize:${payload}`);
    const onResizeCancel = (payload) => events.push(`cancel:${payload}`);

    await render(
      <template>
        <DResizeHandles
          @handles={{state.handles}}
          @onResize={{onResize}}
          @onResizeCancel={{onResizeCancel}}
        />
      </template>
    );

    const cBefore = find(".handle-c");
    stubPointerCapture(".handle-b");
    await triggerEvent(".handle-b", "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 100,
      clientY: 50,
    });
    await triggerEvent(".handle-b", "pointermove", {
      pointerId: 1,
      clientX: 120,
      clientY: 50,
    });

    state.handles = [
      { payload: "a", key: "a", class: "handle-a" },
      { payload: "c", key: "c", class: "handle-c" },
    ];
    await settled();

    assert.deepEqual(
      events,
      ["resize:b", "cancel:b"],
      "the gesture on the removed handle is closed exactly once"
    );
    assert
      .dom(".handle-b")
      .doesNotExist("the removed descriptor's handle is gone");
    // With positional keys the LAST handle goes instead. That destroys `c` and
    // leaves `b` bound to whatever moved into its slot.
    assert.strictEqual(
      find(".handle-c"),
      cBefore,
      "a handle that was not removed keeps its element"
    );
  });

  test("@directions shrinking mid-gesture ends the gesture on the handle it removed", async function (assert) {
    const state = new (class {
      @tracked directions = ["n", "e", "s"];
    })();
    const events = [];
    const onResize = (payload) => events.push(`resize:${payload}`);
    const onResizeCancel = (payload) => events.push(`cancel:${payload}`);

    await render(
      <template>
        <DResizeHandles
          @directions={{state.directions}}
          @handleClass="my-block__handle"
          @onResize={{onResize}}
          @onResizeCancel={{onResizeCancel}}
        />
      </template>
    );

    stubPointerCapture("[data-resize-handle='e']");
    await triggerEvent("[data-resize-handle='e']", "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 100,
      clientY: 50,
    });
    await triggerEvent("[data-resize-handle='e']", "pointermove", {
      pointerId: 1,
      clientX: 120,
      clientY: 50,
    });

    state.directions = ["n", "s"];
    await settled();

    assert.deepEqual(
      events,
      ["resize:e", "cancel:e"],
      "the built-in box closes the gesture on the direction it dropped"
    );
  });

  test("@cancelCommits routes a removed handle's gesture to the commit callback", async function (assert) {
    const state = new (class {
      @tracked
      handles = [
        { payload: "a", key: "a", class: "handle-a" },
        { payload: "b", key: "b", class: "handle-b" },
      ];
    })();
    const ends = [];
    const cancels = [];
    const onResizeEnd = (payload, info) =>
      ends.push(`${payload}:moved=${info.moved}`);
    const onResizeCancel = (payload) => cancels.push(payload);

    await render(
      <template>
        <DResizeHandles
          @cancelCommits={{true}}
          @handles={{state.handles}}
          @onResizeCancel={{onResizeCancel}}
          @onResizeEnd={{onResizeEnd}}
        />
      </template>
    );

    stubPointerCapture(".handle-b");
    await triggerEvent(".handle-b", "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 100,
      clientY: 50,
    });
    await triggerEvent(".handle-b", "pointermove", {
      pointerId: 1,
      clientX: 130,
      clientY: 50,
    });

    state.handles = [{ payload: "a", key: "a", class: "handle-a" }];
    await settled();

    // `moved` has to survive. A handle destroyed before the first move must not
    // look like a resize worth committing.
    assert.deepEqual(ends, ["b:moved=true"], "the commit callback gets it");
    assert.deepEqual(cancels, [], "and the cancel callback stays unreachable");
  });

  test("a recompute that changes nothing leaves a live gesture alone", async function (assert) {
    const state = new (class {
      @tracked seed = 0;

      // A getter over tracked state returns fresh objects on every read. Keys
      // based on object identity would rebuild every handle here and cancel the
      // gesture, which is worse than the bug this fixes. The seed rides along in
      // the class so the test can prove the recompute really happened.
      get handles() {
        return [
          { payload: "a", key: "a", class: `handle-a seed-${this.seed}` },
          { payload: "b", key: "b", class: `handle-b seed-${this.seed}` },
        ];
      }
    })();
    const events = [];
    const onResize = (payload) => events.push(`resize:${payload}`);
    const onResizeCancel = (payload) => events.push(`cancel:${payload}`);
    const onResizeEnd = (payload) => events.push(`end:${payload}`);

    await render(
      <template>
        <DResizeHandles
          @handles={{state.handles}}
          @onResize={{onResize}}
          @onResizeCancel={{onResizeCancel}}
          @onResizeEnd={{onResizeEnd}}
        />
      </template>
    );

    const bBefore = find(".handle-b");
    stubPointerCapture(".handle-b");
    await triggerEvent(".handle-b", "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 100,
      clientY: 50,
    });

    state.seed = 1;
    await settled();

    // Without this the test would pass by never re-rendering at all.
    assert
      .dom(".handle-b")
      .hasClass("seed-1", "control: the descriptors really were rebuilt");

    await triggerEvent(".handle-b", "pointermove", {
      pointerId: 1,
      clientX: 120,
      clientY: 50,
    });
    await triggerEvent(".handle-b", "pointerup", {
      pointerId: 1,
      clientX: 120,
      clientY: 50,
    });

    assert.strictEqual(
      find(".handle-b"),
      bBefore,
      "the handle keeps its element across the recompute"
    );
    assert.deepEqual(
      events,
      ["resize:b", "end:b"],
      "and the gesture runs to its own release, uninterrupted"
    );
  });

  test("handles sharing a payload are told apart", async function (assert) {
    const state = new (class {
      @tracked
      handles = [
        { payload: 0, key: "run-a", class: "handle-run-a" },
        { payload: 0, key: "run-b", class: "handle-run-b" },
        { payload: 1, key: "other", class: "handle-other" },
      ];
    })();
    const events = [];
    const onResizeCancel = (payload) => events.push(`cancel:${payload}`);

    await render(
      <template>
        <DResizeHandles
          @handles={{state.handles}}
          @onResizeCancel={{onResizeCancel}}
        />
      </template>
    );

    assert
      .dom("[data-resize-handle]")
      .exists({ count: 3 }, "a repeated payload is not a duplicate key");

    const runABefore = find(".handle-run-a");
    stubPointerCapture(".handle-run-b");
    await triggerEvent(".handle-run-b", "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 100,
      clientY: 50,
    });

    // One run of a gridline disappears while another run of the same line is
    // being dragged. Both carry the same payload, so the key has to tell them
    // apart.
    state.handles = [
      { payload: 0, key: "run-a", class: "handle-run-a" },
      { payload: 1, key: "other", class: "handle-other" },
    ];
    await settled();

    assert.deepEqual(
      events,
      ["cancel:0"],
      "only the removed run's gesture is closed"
    );
    assert.strictEqual(
      find(".handle-run-a"),
      runABefore,
      "the surviving run of the same payload keeps its element"
    );
  });

  test("removing an earlier twin leaves a gesture on the later one alone", async function (assert) {
    const state = new (class {
      @tracked
      handles = [
        { payload: 0, key: "run-a", class: "handle-run-a" },
        { payload: 0, key: "run-b", class: "handle-run-b" },
      ];
    })();
    const events = [];
    const onResizeCancel = (payload) => events.push(`cancel:${payload}`);

    await render(
      <template>
        <DResizeHandles
          @handles={{state.handles}}
          @onResizeCancel={{onResizeCancel}}
        />
      </template>
    );

    const runBBefore = find(".handle-run-b");
    stubPointerCapture(".handle-run-b");
    await triggerEvent(".handle-run-b", "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 100,
      clientY: 50,
    });

    // The dragged run survives and the one before it goes. Anything positional
    // would shift here and cancel a live gesture; the key does not move.
    state.handles = [{ payload: 0, key: "run-b", class: "handle-run-b" }];
    await settled();

    assert.deepEqual(events, [], "the surviving run keeps its gesture");
    assert.strictEqual(
      find(".handle-run-b"),
      runBBefore,
      "and its element is not rebuilt"
    );
  });

  test("removing a measured handle mid-gesture releases the reflow listeners", async function (assert) {
    const state = new (class {
      @tracked
      handles = [
        { payload: "a", key: "a", class: "handle-a" },
        { payload: "b", key: "b", class: "handle-b" },
      ];
    })();
    const findBox = (handle) =>
      handle.closest(".fixture")?.querySelector(".box");

    await render(
      <template>
        <div class="fixture">
          <div class="box" style="width: 220px; height: 90px"></div>
          <DResizeHandles @handles={{state.handles}} @measure={{findBox}} />
        </div>
      </template>
    );

    stubPointerCapture(".handle-b");
    await triggerEvent(".handle-b", "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 100,
      clientY: 50,
    });

    const removeSpy = sinon.spy(window, "removeEventListener");
    state.handles = [{ payload: "a", key: "a", class: "handle-a" }];
    await settled();

    // A stranded gesture used to leave this document-wide scroll listener
    // attached for the rest of the component's life.
    assert.true(
      removeSpy
        .getCalls()
        .some((call) => call.args[0] === "scroll" && call.args[2] === true),
      "the destroyed handle takes its listeners with it"
    );
  });

  test("@stopPropagation keeps the press from reaching an ancestor", async function (assert) {
    const handles = [{ payload: "e", key: "e", class: "handle-e" }];
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
    const handles = [{ payload: "e", key: "e", class: "handle-e" }];
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
    const handles = [{ payload: "e", key: "e", class: "handle-e" }];
    const events = [];
    const onResize = (payload, info) => events.push(`resize:${info.delta.x}`);
    const onResizeEnd = () => events.push("end");

    await render(
      <template>
        <DResizeHandles
          @handles={{handles}}
          @onResize={{onResize}}
          @onResizeEnd={{onResizeEnd}}
          @threshold={{10}}
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
    const handles = [{ payload: "e", key: "e", class: "handle-e" }];
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
    const handles = [{ payload: "e", key: "e", class: "handle-e" }];
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
    const handles = [{ payload: "e", key: "e", class: "handle-e" }];
    const events = [];
    const onResizeCancel = (payload) => events.push(`cancel:${payload}`);
    const onResizeEnd = (payload) => events.push(`end:${payload}`);

    await render(
      <template>
        <DResizeHandles
          @cancelCommits={{true}}
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

    // Teardown is an end the pointer was never released for, so it reports the
    // way every other such end does rather than inventing a third route.
    assert.deepEqual(
      events,
      ["end:e"],
      "the held gesture commits instead of cancelling"
    );
  });

  test("a throwing consumer cannot abort the teardown of its siblings", async function (assert) {
    const handles = [{ payload: "e", key: "e", class: "handle-e" }];
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
