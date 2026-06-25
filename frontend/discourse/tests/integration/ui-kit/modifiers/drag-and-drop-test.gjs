import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  centerOf,
  dragEvent,
  simulateDrag,
} from "discourse/tests/helpers/ui-kit/drag-and-drop-helper";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";

module("Integration | ui-kit | Modifier | dragAndDrop", function (hooks) {
  setupRenderingTest(hooks);

  test("source + target handshake fires onDrop with source data", async function (assert) {
    const drops = [];
    const onDrop = (payload) => drops.push(payload);

    await render(
      <template>
        <div
          id="src"
          {{dDragAndDropSource type="row" data=(hash id=1)}}
        >src</div>
        <div
          id="tgt"
          {{dDragAndDropTarget accepts="row" position="before" onDrop=onDrop}}
        >tgt</div>
      </template>
    );

    const dataTransfer = new DataTransfer();
    await simulateDrag("#src", "#tgt", { dataTransfer });

    assert.strictEqual(drops.length, 1, "onDrop fires once");
    assert.strictEqual(drops[0].position, "before");
    assert.deepEqual(drops[0].source.data, { type: "row", id: 1 });
    assert.strictEqual(drops[0].source.type, "row");
  });

  test("type discriminator gates compatibility", async function (assert) {
    let dropped = false;
    const onDrop = () => {
      dropped = true;
    };

    await render(
      <template>
        <div
          id="src"
          {{dDragAndDropSource type="row" data=(hash id=1)}}
        >src</div>
        <div
          id="tgt"
          {{dDragAndDropTarget accepts="card" onDrop=onDrop}}
        >tgt</div>
      </template>
    );

    const dataTransfer = new DataTransfer();
    await simulateDrag("#src", "#tgt", { dataTransfer });

    assert.false(dropped, "onDrop is not called for foreign types");
  });

  test("source toggles is-dragging during the drag", async function (assert) {
    await render(
      <template>
        <div
          id="src"
          {{dDragAndDropSource type="row" data=(hash id=1)}}
        >src</div>
      </template>
    );

    const dataTransfer = new DataTransfer();
    await dragEvent("#src", "dragstart", { dataTransfer, ...centerOf("#src") });
    assert.dom("#src").hasClass("is-dragging");
    await dragEvent("#src", "dragend", { dataTransfer, ...centerOf("#src") });
    assert.dom("#src").doesNotHaveClass("is-dragging");
  });

  test("smart row mode resolves position from cursor midpoint", async function (assert) {
    const drops = [];
    const onDrop = (payload) => drops.push(payload);

    await render(
      <template>
        <div
          id="src"
          {{dDragAndDropSource type="row" data=(hash id=1)}}
        >src</div>
        <div
          id="tgt"
          style="height: 100px"
          {{dDragAndDropTarget accepts="row" onDrop=onDrop}}
        >tgt</div>
      </template>
    );

    const dataTransfer = new DataTransfer();
    const target = document.querySelector("#tgt");
    const rect = target.getBoundingClientRect();

    await dragEvent("#src", "dragstart", { dataTransfer, ...centerOf("#src") });
    await dragEvent("#tgt", "dragenter", { dataTransfer, ...centerOf("#tgt") });
    await dragEvent("#tgt", "dragover", {
      dataTransfer,
      clientY: rect.top + 5,
      clientX: rect.left + 5,
    });
    await dragEvent("#tgt", "drop", {
      dataTransfer,
      clientY: rect.top + 5,
      clientX: rect.left + 5,
    });
    await dragEvent("#src", "dragend", { dataTransfer, ...centerOf("#src") });

    assert.strictEqual(drops.at(-1).position, "before");

    drops.length = 0;
    const dataTransfer2 = new DataTransfer();
    await dragEvent("#src", "dragstart", {
      dataTransfer: dataTransfer2,
      ...centerOf("#src"),
    });
    await dragEvent("#tgt", "dragenter", {
      dataTransfer: dataTransfer2,
      ...centerOf("#tgt"),
    });
    await dragEvent("#tgt", "dragover", {
      dataTransfer: dataTransfer2,
      clientY: rect.top + rect.height - 5,
      clientX: rect.left + 5,
    });
    await dragEvent("#tgt", "drop", {
      dataTransfer: dataTransfer2,
      clientY: rect.top + rect.height - 5,
      clientX: rect.left + 5,
    });
    await dragEvent("#src", "dragend", {
      dataTransfer: dataTransfer2,
      ...centerOf("#src"),
    });

    assert.strictEqual(drops.at(-1).position, "after");
  });

  test("nested targets — innermost accepting target wins drop", async function (assert) {
    const events = [];
    const onOuterDrop = () => events.push("outer");
    const onInnerDrop = () => events.push("inner");

    await render(
      <template>
        <div
          id="src"
          {{dDragAndDropSource type="row" data=(hash id=1)}}
        >src</div>
        <div
          id="outer"
          {{dDragAndDropTarget
            accepts="row"
            position="inside"
            onDrop=onOuterDrop
          }}
        >
          outer
          <div
            id="inner"
            {{dDragAndDropTarget
              accepts="row"
              position="before"
              onDrop=onInnerDrop
            }}
          >inner</div>
        </div>
      </template>
    );

    const dataTransfer = new DataTransfer();
    await simulateDrag("#src", "#inner", { dataTransfer });

    assert.deepEqual(
      events,
      ["inner"],
      "only the deepest accepted target receives the drop"
    );
  });

  test("target modifier picks up arg changes without re-registering", async function (assert) {
    // The modifier runs `modify()` only once (its body reads no tracked
    // arg properties), so PDND is registered just once. The closure
    // around `args` must still see updated values when tracked args
    // change. This guards against the modifier going stale after an
    // arg update.
    const state = new (class {
      @tracked accepted = "row";
      @tracked dropped = null;
      handleDrop = (payload) => (this.dropped = payload.source.type);
    })();

    await render(
      <template>
        <div
          id="src-row"
          {{dDragAndDropSource type="row" data=(hash id=1)}}
        >src-row</div>
        <div
          id="src-card"
          {{dDragAndDropSource type="card" data=(hash id=2)}}
        >src-card</div>
        <div
          id="tgt"
          {{dDragAndDropTarget accepts=state.accepted onDrop=state.handleDrop}}
        >tgt</div>
      </template>
    );

    let dataTransfer = new DataTransfer();
    await simulateDrag("#src-row", "#tgt", { dataTransfer });
    assert.strictEqual(
      state.dropped,
      "row",
      "drops the type currently in `accepts`"
    );

    state.accepted = "card";
    state.dropped = null;
    await settled();

    dataTransfer = new DataTransfer();
    await simulateDrag("#src-row", "#tgt", { dataTransfer });
    assert.strictEqual(
      state.dropped,
      null,
      "after arg update, the old accepted type is rejected"
    );

    dataTransfer = new DataTransfer();
    await simulateDrag("#src-card", "#tgt", { dataTransfer });
    assert.strictEqual(
      state.dropped,
      "card",
      "after arg update, the new accepted type fires onDrop"
    );
  });

  test("the service tracks the element drag first-hand", async function (assert) {
    // The source modifier no longer pushes drag state; the service derives it
    // via its own `monitorForElements`. Looking the service up registers that
    // monitor before the drag begins.
    const dnd = this.owner.lookup("service:drag-and-drop");

    await render(
      <template>
        <div id="src" {{dDragAndDropSource type="row" data=(hash id=1)}}>
          src
        </div>
      </template>
    );

    assert.false(dnd.isDragging, "no drag in flight before dragstart");

    const dataTransfer = new DataTransfer();
    await dragEvent("#src", "dragstart", { dataTransfer, ...centerOf("#src") });

    assert.true(dnd.isDragging, "isDragging is true during the drag");
    assert.true(dnd.accepts("row"), "accepts the in-flight type");
    assert.false(dnd.accepts("card"), "rejects a foreign type");
    assert.strictEqual(dnd.currentDrag.type, "row", "currentDrag carries type");
    assert.deepEqual(
      dnd.currentDrag.data,
      { type: "row", id: 1 },
      "currentDrag.data carries the source payload"
    );
    assert.strictEqual(
      dnd.currentDrag.element,
      document.querySelector("#src"),
      "currentDrag.element is the source element"
    );

    await dragEvent("#src", "dragend", { dataTransfer, ...centerOf("#src") });

    assert.strictEqual(dnd.currentDrag, null, "cleared once the drag ends");
    assert.false(dnd.isDragging, "isDragging is false after the drag");
  });

  test("currentDrag identity is stable within a drag (one object per drag)", async function (assert) {
    // grid-overlay keys its drag cache on the `currentDrag` reference, so the
    // service must set it once per drag, not rebuild it per move.
    const dnd = this.owner.lookup("service:drag-and-drop");

    await render(
      <template>
        <div id="src" {{dDragAndDropSource type="row" data=(hash id=1)}}>
          src
        </div>
      </template>
    );

    const dataTransfer = new DataTransfer();
    await dragEvent("#src", "dragstart", { dataTransfer, ...centerOf("#src") });
    const first = dnd.currentDrag;
    await dragEvent("#src", "dragover", { dataTransfer, ...centerOf("#src") });
    assert.strictEqual(
      dnd.currentDrag,
      first,
      "the reference is unchanged across drag moves"
    );
    await dragEvent("#src", "dragend", { dataTransfer, ...centerOf("#src") });
  });
});
