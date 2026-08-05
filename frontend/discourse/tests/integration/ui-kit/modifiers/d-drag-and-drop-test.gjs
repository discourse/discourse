import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { find, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  centerOf,
  dragEvent,
  simulateDrag,
} from "discourse/tests/helpers/ui-kit/drag-and-drop-helper";
import dDragAndDropExternalTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-external-target";
import { registerDragAndDropMonitor } from "discourse/ui-kit/modifiers/d-drag-and-drop-monitor";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";

module("Integration | ui-kit | Modifier | dragAndDrop", function (hooks) {
  setupRenderingTest(hooks);

  module("marker attribute lifecycle", function () {
    test("marks every registered element after render", async function (assert) {
      await render(
        <template>
          <div id="source" {{dDragAndDropSource type="row"}}>source</div>
          <div id="target" {{dDragAndDropTarget accepts="row"}}>target</div>
          <div
            id="external-target"
            {{dDragAndDropExternalTarget accepts="files"}}
          >external target</div>
        </template>
      );

      assert
        .dom("#source")
        .hasAttribute(
          "data-drag-source",
          "",
          "the source has its registration marker"
        );
      assert
        .dom("#target")
        .hasAttribute(
          "data-drop-target",
          "",
          "the element target has its registration marker"
        );
      assert
        .dom("#external-target")
        .hasAttribute(
          "data-drop-target-external",
          "",
          "the external target has its registration marker"
        );
    });

    test("removes every marker when its element is destroyed", async function (assert) {
      const state = new (class {
        @tracked show = true;
      })();

      await render(
        <template>
          {{#if state.show}}
            <div id="source" {{dDragAndDropSource type="row"}}>source</div>
            <div id="target" {{dDragAndDropTarget accepts="row"}}>target</div>
            <div
              id="external-target"
              {{dDragAndDropExternalTarget accepts="files"}}
            >external target</div>
          {{/if}}
        </template>
      );

      const source = find("#source");
      const target = find("#target");
      const externalTarget = find("#external-target");

      assert.true(
        source.hasAttribute("data-drag-source"),
        "the source starts registered"
      );
      assert.true(
        target.hasAttribute("data-drop-target"),
        "the element target starts registered"
      );
      assert.true(
        externalTarget.hasAttribute("data-drop-target-external"),
        "the external target starts registered"
      );

      state.show = false;
      await settled();

      assert.false(
        source.hasAttribute("data-drag-source"),
        "destroying the source removes its marker"
      );
      assert.false(
        target.hasAttribute("data-drop-target"),
        "destroying the element target removes its marker"
      );
      assert.false(
        externalTarget.hasAttribute("data-drop-target-external"),
        "destroying the external target removes its marker"
      );
    });

    test("source marker follows the disabled registration cycle", async function (assert) {
      const state = new (class {
        @tracked disabled = false;
      })();

      await render(
        <template>
          <div
            id="source"
            {{dDragAndDropSource type="row" disabled=state.disabled}}
          >source</div>
        </template>
      );

      const source = find("#source");
      assert.true(
        source.hasAttribute("data-drag-source"),
        "the enabled source is marked"
      );

      state.disabled = true;
      await settled();
      assert.false(
        source.hasAttribute("data-drag-source"),
        "disabling removes the marker from the live element"
      );

      state.disabled = false;
      await settled();
      assert.true(
        source.hasAttribute("data-drag-source"),
        "re-enabling restores the marker on the same element"
      );
    });
  });

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

  test("simulateDrag merges independent partial coordinate overrides", async function (assert) {
    const events = {};

    await render(
      <template>
        <div id="src">source</div>
        <div id="tgt">target</div>
      </template>
    );

    for (const type of ["dragstart", "dragend"]) {
      find("#src").addEventListener(type, (event) => {
        events[type] = { clientX: event.clientX, clientY: event.clientY };
      });
    }
    for (const type of ["dragenter", "dragover", "drop"]) {
      find("#tgt").addEventListener(type, (event) => {
        events[type] = { clientX: event.clientX, clientY: event.clientY };
      });
    }

    const sourceCenter = centerOf("#src");
    const targetCenter = centerOf("#tgt");
    const sourceCoordinates = { clientY: sourceCenter.clientY - 1 };
    const targetCoordinates = { clientX: targetCenter.clientX + 1 };

    await simulateDrag("#src", "#tgt", {
      dataTransfer: new DataTransfer(),
      sourceCoordinates,
      targetCoordinates,
    });

    assert.strictEqual(
      events.dragstart.clientY,
      sourceCoordinates.clientY,
      "dragstart uses the source clientY override"
    );
    assert.strictEqual(
      events.dragstart.clientX,
      sourceCenter.clientX,
      "dragstart keeps the computed source clientX"
    );
    assert.strictEqual(
      events.dragend.clientY,
      sourceCoordinates.clientY,
      "dragend uses the source clientY override"
    );
    assert.strictEqual(
      events.dragend.clientX,
      sourceCenter.clientX,
      "dragend keeps the computed source clientX"
    );
    for (const type of ["dragenter", "dragover", "drop"]) {
      assert.strictEqual(
        events[type].clientX,
        targetCoordinates.clientX,
        `${type} uses the target clientX override`
      );
      assert.strictEqual(
        events[type].clientY,
        targetCenter.clientY,
        `${type} keeps the computed target clientY`
      );
    }
  });

  test("source without dragHandle starts from the whole element", async function (assert) {
    let starts = 0;
    const onDragStart = () => starts++;

    await render(
      <template>
        <div id="src" {{dDragAndDropSource type="row" onDragStart=onDragStart}}>
          <span id="body">body</span>
        </div>
        <div id="tgt" {{dDragAndDropTarget accepts="row"}}>target</div>
      </template>
    );

    await simulateDrag("#src", "#tgt", {
      dataTransfer: new DataTransfer(),
      sourceCoordinates: centerOf("#body"),
    });

    assert.strictEqual(starts, 1, "pressing the row body starts the drag");
  });

  test("source re-registers when dragHandle arrives after initial registration", async function (assert) {
    const state = new (class {
      @tracked showHandle = false;
      @tracked dragHandle;
      starts = 0;
      captureHandle = (element) => (this.dragHandle = element);
      onDragStart = () => this.starts++;
    })();

    await render(
      <template>
        <div
          id="src"
          {{dDragAndDropSource
            type="row"
            dragHandle=state.dragHandle
            onDragStart=state.onDragStart
          }}
        >
          <span id="body">body</span>
          {{#if state.showHandle}}
            <button id="handle" type="button" {{didInsert state.captureHandle}}>
              handle
            </button>
          {{/if}}
        </div>
        <div id="tgt" {{dDragAndDropTarget accepts="row"}}>target</div>
      </template>
    );

    state.showHandle = true;
    await settled();

    await simulateDrag("#src", "#tgt", {
      dataTransfer: new DataTransfer(),
      sourceCoordinates: centerOf("#body"),
    });
    assert.strictEqual(
      state.starts,
      0,
      "after the handle arrives, pressing the row body does not start a drag"
    );

    await simulateDrag("#src", "#tgt", {
      dataTransfer: new DataTransfer(),
      sourceCoordinates: centerOf("#handle"),
    });
    assert.strictEqual(
      state.starts,
      1,
      "after the handle arrives, pressing the handle starts a drag"
    );
  });

  test("source re-registers when dragHandle changes identity", async function (assert) {
    const state = new (class {
      @tracked showSecondHandle = false;
      @tracked dragHandle;
      starts = 0;
      captureHandle = (element) => (this.dragHandle = element);
      onDragStart = () => this.starts++;
    })();

    await render(
      <template>
        <div
          id="src"
          {{dDragAndDropSource
            type="row"
            dragHandle=state.dragHandle
            onDragStart=state.onDragStart
          }}
        >
          <button
            id="first-handle"
            type="button"
            {{didInsert state.captureHandle}}
          >
            first
          </button>
          {{#if state.showSecondHandle}}
            <button
              id="second-handle"
              type="button"
              {{didInsert state.captureHandle}}
            >
              second
            </button>
          {{/if}}
        </div>
        <div id="tgt" {{dDragAndDropTarget accepts="row"}}>target</div>
      </template>
    );

    state.showSecondHandle = true;
    await settled();

    await simulateDrag("#src", "#tgt", {
      dataTransfer: new DataTransfer(),
      sourceCoordinates: centerOf("#first-handle"),
    });
    assert.strictEqual(
      state.starts,
      0,
      "pressing the previous handle does not start a drag"
    );

    await simulateDrag("#src", "#tgt", {
      dataTransfer: new DataTransfer(),
      sourceCoordinates: centerOf("#second-handle"),
    });
    assert.strictEqual(
      state.starts,
      1,
      "pressing the replacement handle starts a drag"
    );
  });

  test("source re-registers when dragHandle is removed", async function (assert) {
    const state = new (class {
      @tracked dragHandle;
      @tracked useHandle = true;
      starts = 0;
      captureHandle = (element) => (this.dragHandle = element);
      onDragStart = () => this.starts++;
    })();

    await render(
      <template>
        <div
          id="src"
          {{dDragAndDropSource
            type="row"
            dragHandle=(if state.useHandle state.dragHandle)
            onDragStart=state.onDragStart
          }}
        >
          <span id="body">body</span>
          <button id="handle" type="button" {{didInsert state.captureHandle}}>
            handle
          </button>
        </div>
        <div id="tgt" {{dDragAndDropTarget accepts="row"}}>target</div>
      </template>
    );

    await simulateDrag("#src", "#tgt", {
      dataTransfer: new DataTransfer(),
      sourceCoordinates: centerOf("#body"),
    });
    assert.strictEqual(
      state.starts,
      0,
      "while the handle is configured, pressing the row body does not drag"
    );

    state.useHandle = false;
    await settled();

    await simulateDrag("#src", "#tgt", {
      dataTransfer: new DataTransfer(),
      sourceCoordinates: centerOf("#body"),
    });
    assert.strictEqual(
      state.starts,
      1,
      "after removing the handle, pressing the row body starts a drag"
    );
  });

  test("target accepts a self drop by default", async function (assert) {
    let drops = 0;
    const onDrop = () => drops++;

    await render(
      <template>
        <div
          id="row"
          {{dDragAndDropSource type="row"}}
          {{dDragAndDropTarget accepts="row" onDrop=onDrop}}
        >row</div>
      </template>
    );

    await simulateDrag("#row", "#row", {
      dataTransfer: new DataTransfer(),
    });

    assert.strictEqual(drops, 1, "self drops remain enabled when omitted");
  });

  test("target with acceptsSelf=false rejects its own source element", async function (assert) {
    let drops = 0;
    const onDrop = () => drops++;

    await render(
      <template>
        <div
          id="row"
          {{dDragAndDropSource type="row"}}
          {{dDragAndDropTarget accepts="row" acceptsSelf=false onDrop=onDrop}}
        >row</div>
      </template>
    );

    await simulateDrag("#row", "#row", {
      dataTransfer: new DataTransfer(),
    });

    assert.strictEqual(drops, 0, "the target refuses its own source element");
  });

  test("acceptsSelf checks the raw source element without target fallback", async function (assert) {
    let drops = 0;
    const onDrop = () => drops++;
    const cleanupMonitor = registerDragAndDropMonitor(() => ({
      onDragStart: ({ source }) => delete source.element,
    }));

    await render(
      <template>
        <div id="src" {{dDragAndDropSource type="row"}}>source</div>
        <div
          id="tgt"
          {{dDragAndDropTarget accepts="row" acceptsSelf=false onDrop=onDrop}}
        >target</div>
      </template>
    );

    await simulateDrag("#src", "#tgt", {
      dataTransfer: new DataTransfer(),
    });
    cleanupMonitor();

    assert.strictEqual(
      drops,
      1,
      "a missing raw source element is not treated as the target element"
    );
  });

  test("source toggles --dragging during the drag", async function (assert) {
    await render(
      <template>
        <div
          id="src"
          {{dDragAndDropSource type="row" data=(hash id=1)}}
        >src</div>
      </template>
    );

    assert
      .dom("#src")
      .hasAttribute(
        "data-drag-source",
        "",
        "the style hook is present for the whole registration, not only mid-drag"
      );

    const dataTransfer = new DataTransfer();
    await dragEvent("#src", "dragstart", { dataTransfer, ...centerOf("#src") });
    assert.dom("#src").hasClass("--dragging");
    await dragEvent("#src", "dragend", { dataTransfer, ...centerOf("#src") });
    assert.dom("#src").doesNotHaveClass("--dragging");
  });

  test("cancelled source drag cleans up without firing consumer onDrop", async function (assert) {
    let drops = 0;
    const onDrop = () => drops++;

    await render(
      <template>
        <div id="src" {{dDragAndDropSource type="row" onDrop=onDrop}}>
          src
        </div>
      </template>
    );

    const dataTransfer = new DataTransfer();
    await dragEvent("#src", "dragstart", {
      dataTransfer,
      ...centerOf("#src"),
    });
    await dragEvent("#src", "dragend", {
      dataTransfer,
      ...centerOf("#src"),
    });

    assert
      .dom("#src")
      .doesNotHaveClass(
        "--dragging",
        "a cancelled drag still removes the source-private dragging class"
      );
    assert.strictEqual(
      drops,
      0,
      "a cancelled drag does not fire the consumer's onDrop"
    );
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

  test("dropping on a nested target clears the ancestor indicator", async function (assert) {
    await render(
      <template>
        <div id="src" {{dDragAndDropSource type="row"}}>src</div>
        <div
          id="outer"
          style="height: 100px"
          {{dDragAndDropTarget accepts="row" position="inside"}}
        >
          outer
          <div
            id="inner"
            {{dDragAndDropTarget accepts="row" position="inside"}}
          >inner</div>
        </div>
      </template>
    );

    const dataTransfer = new DataTransfer();
    const outerRect = find("#outer").getBoundingClientRect();

    await dragEvent("#src", "dragstart", {
      dataTransfer,
      ...centerOf("#src"),
    });
    await dragEvent("#outer", "dragenter", {
      dataTransfer,
      clientX: outerRect.left + 5,
      clientY: outerRect.top + 5,
    });
    await dragEvent("#outer", "dragover", {
      dataTransfer,
      clientX: outerRect.left + 5,
      clientY: outerRect.top + 5,
    });

    assert
      .dom("#outer")
      .hasClass("--drag-inside", "the parent paints its indicator first");

    await dragEvent("#inner", "dragenter", {
      dataTransfer,
      ...centerOf("#inner"),
    });
    await dragEvent("#inner", "dragover", {
      dataTransfer,
      ...centerOf("#inner"),
    });
    await dragEvent("#inner", "drop", {
      dataTransfer,
      ...centerOf("#inner"),
    });
    await dragEvent("#src", "dragend", {
      dataTransfer,
      ...centerOf("#src"),
    });

    assert
      .dom("#outer")
      .doesNotHaveClass(
        "--drag-inside",
        "dropping on the child clears the parent indicator"
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
