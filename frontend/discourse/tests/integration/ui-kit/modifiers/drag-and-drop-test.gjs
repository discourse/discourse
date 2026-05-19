import { hash } from "@ember/helper";
import { render, settled, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";

/**
 * Drives a full HTML5 drag/drop cycle between a source and a target
 * through the test runner. PDND wraps the native DnD events under the
 * hood, so its callbacks fire when the matching DOM events are
 * dispatched.
 */
async function dragFromTo(sourceSelector, targetSelector, { dataTransfer }) {
  await triggerEvent(sourceSelector, "dragstart", { dataTransfer });
  await triggerEvent(targetSelector, "dragenter", { dataTransfer });
  await triggerEvent(targetSelector, "dragover", { dataTransfer });
  await triggerEvent(targetSelector, "drop", { dataTransfer });
  await triggerEvent(sourceSelector, "dragend", { dataTransfer });
}

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
    await dragFromTo("#src", "#tgt", { dataTransfer });

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
    await dragFromTo("#src", "#tgt", { dataTransfer });

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
    await triggerEvent("#src", "dragstart", { dataTransfer });
    assert.dom("#src").hasClass("is-dragging");
    await triggerEvent("#src", "dragend", { dataTransfer });
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

    await triggerEvent("#src", "dragstart", { dataTransfer });
    // Drop at the top half — should resolve "before".
    await triggerEvent("#tgt", "dragenter", { dataTransfer });
    await triggerEvent("#tgt", "dragover", {
      dataTransfer,
      clientY: rect.top + 5,
      clientX: rect.left + 5,
    });
    await triggerEvent("#tgt", "drop", {
      dataTransfer,
      clientY: rect.top + 5,
      clientX: rect.left + 5,
    });
    await triggerEvent("#src", "dragend", { dataTransfer });

    assert.strictEqual(drops.at(-1).position, "before");

    // Second drag, drop near the bottom edge — should resolve "after".
    drops.length = 0;
    const dataTransfer2 = new DataTransfer();
    await triggerEvent("#src", "dragstart", { dataTransfer: dataTransfer2 });
    await triggerEvent("#tgt", "dragenter", { dataTransfer: dataTransfer2 });
    await triggerEvent("#tgt", "dragover", {
      dataTransfer: dataTransfer2,
      clientY: rect.top + rect.height - 5,
      clientX: rect.left + 5,
    });
    await triggerEvent("#tgt", "drop", {
      dataTransfer: dataTransfer2,
      clientY: rect.top + rect.height - 5,
      clientX: rect.left + 5,
    });
    await triggerEvent("#src", "dragend", { dataTransfer: dataTransfer2 });

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
    await dragFromTo("#src", "#inner", { dataTransfer });
    await settled();

    assert.deepEqual(
      events,
      ["inner"],
      "only the deepest accepted target receives the drop"
    );
  });
});
