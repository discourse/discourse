import { tracked } from "@glimmer/tracking";
import { find, render, settled, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
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

  test("@handleClass renders the 8-direction box with BEM classes", async function (assert) {
    await render(
      <template><DResizeHandles @handleClass="my-block__handle" /></template>
    );

    assert
      .dom("[data-resize-handle]")
      .exists({ count: 8 }, "renders the eight compass handles");
    assert
      .dom("[data-resize-handle='ne']")
      .hasClass("my-block__handle", "applies the base class")
      .hasClass("my-block__handle--ne", "applies the per-direction modifier");
    assert
      .dom("[data-resize-handle='w']")
      .hasClass("my-block__handle--w", "each direction gets its modifier");
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

  test("a vetoed press starts no gesture", async function (assert) {
    const handles = [{ payload: "e", class: "handle-e" }];
    const events = [];
    const onResizeStart = () => false;
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
    // currently bound to.
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
});
