import { render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
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
});
