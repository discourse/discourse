import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import {
  clearRender,
  find,
  render,
  settled,
  setupOnerror,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  centerOf,
  dragEvent,
  dragEventNow,
  dragOver,
  simulateDrag,
  startDrag,
} from "discourse/tests/helpers/ui-kit/drag-and-drop-helper";
import { registerDragAndDropMonitor } from "discourse/ui-kit/modifiers/d-drag-and-drop-monitor";
import dDragAndDropSource, {
  registerDragAndDropSource,
} from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";

module("Integration | ui-kit | Modifier | dragAndDrop", function (hooks) {
  setupRenderingTest(hooks);

  module("marker attribute lifecycle", function () {
    test("removes every marker when its element is destroyed", async function (assert) {
      const state = new (class {
        @tracked show = true;
      })();

      await render(
        <template>
          {{#if state.show}}
            <div id="source" {{dDragAndDropSource type="row"}}>source</div>
            <div id="target" {{dDragAndDropTarget accepts="row"}}>target</div>
          {{/if}}
        </template>
      );

      const source = find("#source");
      const target = find("#target");

      assert.true(
        source.hasAttribute("data-drag-source"),
        "the source starts registered"
      );
      assert.true(
        target.hasAttribute("data-drop-target"),
        "the element target starts registered"
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

  test("a source without a handle is draggable itself", async function (assert) {
    await render(
      <template>
        <div id="src" {{dDragAndDropSource type="row"}}>src</div>
      </template>
    );

    assert.dom("#src").hasAttribute("draggable", "true");
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

    // The handle takes over the registration, which is what the browser reads
    // to decide a press can begin a drag at all. Asserting the attribute rather
    // than a coordinate is the honest form: a press on the row body cannot
    // produce a `dragstart` once the row is no longer draggable, so a synthetic
    // one dispatched there would be testing a state the browser never reaches.
    assert.dom("#src").doesNotHaveAttribute("draggable");
    assert.dom("#handle").hasAttribute("draggable", "true");

    await simulateDrag("#src", "#tgt", {
      dataTransfer: new DataTransfer(),
    });
    assert.strictEqual(
      state.starts,
      1,
      "after the handle arrives, a drag from it still reaches the source"
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

    // The registration moves with the handle, so the replaced one stops being
    // draggable and the replacement starts. Without the first assertion a stale
    // registration would leave two draggable elements and the row would drag
    // from a handle it no longer recognises.
    assert.dom("#first-handle").doesNotHaveAttribute("draggable");
    assert.dom("#second-handle").hasAttribute("draggable", "true");

    await simulateDrag("#src", "#tgt", {
      dataTransfer: new DataTransfer(),
    });
    assert.strictEqual(
      state.starts,
      1,
      "a drag from the replacement handle reaches the source"
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

    // While a handle is configured the row itself is not draggable, so a press
    // on its body is an ordinary press — which is what leaves the text there
    // selectable.
    assert.dom("#src").doesNotHaveAttribute("draggable");
    assert.dom("#handle").hasAttribute("draggable", "true");

    state.useHandle = false;
    await settled();

    assert.dom("#handle").doesNotHaveAttribute("draggable");
    assert.dom("#src").hasAttribute("draggable", "true");

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

  test("a handled row with acceptsSelf=false refuses its own body, and a target reads the row as source.element", async function (assert) {
    const drops = [];
    const recordDrop = ({ source }) => drops.push(source.element);
    const state = new (class {
      @tracked dragHandle;
      captureHandle = (element) => (this.dragHandle = element);
    })();

    await render(
      <template>
        <div
          id="row"
          {{dDragAndDropSource type="row" dragHandle=state.dragHandle}}
          {{dDragAndDropTarget
            accepts="row"
            acceptsSelf=false
            onDrop=recordDrop
          }}
        >
          <button id="grip" type="button" {{didInsert state.captureHandle}}>
            grip
          </button>
        </div>
        <div id="other" {{dDragAndDropTarget accepts="row" onDrop=recordDrop}}>
          other
        </div>
      </template>
    );

    await simulateDrag("#row", "#row", { dataTransfer: new DataTransfer() });
    assert.deepEqual(
      drops,
      [],
      "the row refuses a drop of itself even though the grip is what was registered"
    );

    await simulateDrag("#row", "#other", { dataTransfer: new DataTransfer() });
    assert.deepEqual(
      drops,
      [find("#row")],
      "another target is handed the row, not the grip"
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

  module("source end callbacks", function () {
    test("abandoned drag defers onDragEnd without onDrop", async function (assert) {
      const calls = [];
      let dragEndPayload;
      const onDragEnd = (payload) => {
        dragEndPayload = payload;
        calls.push("onDragEnd");
      };
      const onDrop = () => calls.push("onDrop");

      await render(
        <template>
          <div
            id="src"
            {{dDragAndDropSource
              type="row"
              data=(hash id=1)
              onDragEnd=onDragEnd
              onDrop=onDrop
            }}
          >src</div>
        </template>
      );

      find("#src").addEventListener("dragend", () =>
        calls.push("native dragend")
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

      assert.deepEqual(
        {
          calls,
          sourceData: dragEndPayload?.source.data ?? null,
          hasSourceElement: dragEndPayload?.source.element === find("#src"),
          dropTargetCount:
            dragEndPayload?.location.current.dropTargets.length ?? null,
        },
        {
          calls: ["native dragend", "onDragEnd"],
          sourceData: { type: "row", id: 1 },
          hasSourceElement: true,
          dropTargetCount: 0,
        },
        "an abandoned drag defers onDragEnd with its snapshot and does not fire onDrop"
      );
    });

    test("landed drag defers onDragEnd before onDrop with the same payload", async function (assert) {
      const calls = [];
      const onDragEnd = (payload) => calls.push({ name: "onDragEnd", payload });
      const onDrop = (payload) => calls.push({ name: "onDrop", payload });

      await render(
        <template>
          <div
            id="src"
            {{dDragAndDropSource
              type="row"
              data=(hash id=1)
              onDragEnd=onDragEnd
              onDrop=onDrop
            }}
          >src</div>
          <div id="tgt" {{dDragAndDropTarget accepts="row"}}>target</div>
        </template>
      );

      find("#tgt").addEventListener("drop", () =>
        calls.push({ name: "native drop" })
      );

      await simulateDrag("#src", "#tgt", {
        dataTransfer: new DataTransfer(),
      });

      const dragEndPayload = calls.find(
        ({ name }) => name === "onDragEnd"
      )?.payload;
      const dropPayload = calls.find(({ name }) => name === "onDrop")?.payload;

      assert.deepEqual(
        {
          calls: calls.map(({ name }) => name),
          sharesSource: dragEndPayload?.source === dropPayload?.source,
          sharesLocation: dragEndPayload?.location === dropPayload?.location,
          sourceData: dragEndPayload?.source.data ?? null,
        },
        {
          calls: ["native drop", "onDragEnd", "onDrop"],
          sharesSource: true,
          sharesLocation: true,
          sourceData: { type: "row", id: 1 },
        },
        "a landed drag defers onDragEnd before onDrop with the same snapshot"
      );
    });

    test("landed drag fires onDragEnd once across multiple drop targets", async function (assert) {
      const dragEnds = [];
      const onDragEnd = (payload) => dragEnds.push(payload);

      await render(
        <template>
          <div
            id="src"
            {{dDragAndDropSource type="row" onDragEnd=onDragEnd}}
          >src</div>
          <div id="outer" {{dDragAndDropTarget accepts="row"}}>
            outer
            <div id="inner" {{dDragAndDropTarget accepts="row"}}>inner</div>
          </div>
        </template>
      );

      await simulateDrag("#src", "#inner", {
        dataTransfer: new DataTransfer(),
      });

      assert.deepEqual(
        {
          callbackCount: dragEnds.length,
          dropTargetCount:
            dragEnds[0]?.location.current.dropTargets.length ?? 0,
        },
        { callbackCount: 1, dropTargetCount: 2 },
        "onDragEnd fires once for a drag that lands on two nested targets"
      );
    });
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

    const rect = find("#tgt").getBoundingClientRect();

    await simulateDrag("#src", "#tgt", {
      dataTransfer: new DataTransfer(),
      targetCoordinates: { clientY: rect.top + 5 },
    });
    await simulateDrag("#src", "#tgt", {
      dataTransfer: new DataTransfer(),
      targetCoordinates: { clientY: rect.top + rect.height - 5 },
    });

    assert.deepEqual(
      drops.map(({ position }) => position),
      ["before", "after"],
      "a drop lands before or after the target depending on which side of its midpoint the cursor is"
    );
  });

  test("a horizontal target measures the midpoint along x and lights the side class", async function (assert) {
    const drops = [];
    const onDrop = (payload) => drops.push(payload.position);

    await render(
      <template>
        <div
          id="src"
          {{dDragAndDropSource type="col" data=(hash id=1)}}
        >src</div>
        <div
          id="tgt"
          style="width: 200px; height: 20px"
          {{dDragAndDropTarget accepts="col" axis="horizontal" onDrop=onDrop}}
        >tgt</div>
      </template>
    );

    const dataTransfer = new DataTransfer();
    const rect = find("#tgt").getBoundingClientRect();
    // Deep in the vertical lower half, so a target still measuring y reads
    // "after" and lights `--drag-below` instead.
    const nearLeftEdge = {
      clientX: rect.left + 5,
      clientY: rect.top + rect.height - 2,
    };

    await dragEvent("#src", "dragstart", { dataTransfer, ...centerOf("#src") });
    await dragEvent("#tgt", "dragenter", { dataTransfer, ...nearLeftEdge });
    await dragEvent("#tgt", "dragover", { dataTransfer, ...nearLeftEdge });

    assert
      .dom("#tgt")
      .hasClass("--drag-left", "the indicator names the horizontal side");
    assert.dom("#tgt").doesNotHaveClass("--drag-below");

    await dragEvent("#tgt", "drop", { dataTransfer, ...nearLeftEdge });
    await dragEvent("#src", "dragend", { dataTransfer, ...centerOf("#src") });

    assert.deepEqual(drops, ["before"], "the midpoint is measured along x");
  });

  test("a horizontal target in RTL reports the logical side and lights the physical one", async function (assert) {
    const drops = [];
    const onDrop = (payload) => drops.push(payload.position);

    await render(
      <template>
        <div
          id="src"
          {{dDragAndDropSource type="col" data=(hash id=1)}}
        >src</div>
        <div
          id="tgt"
          style="width: 200px; height: 20px; direction: rtl"
          {{dDragAndDropTarget accepts="col" axis="horizontal" onDrop=onDrop}}
        >tgt</div>
      </template>
    );

    const dataTransfer = new DataTransfer();
    const rect = find("#tgt").getBoundingClientRect();
    const nearLeftEdge = {
      clientX: rect.left + 5,
      clientY: rect.top + rect.height / 2,
    };

    await dragEvent("#src", "dragstart", { dataTransfer, ...centerOf("#src") });
    await dragEvent("#tgt", "dragenter", { dataTransfer, ...nearLeftEdge });
    await dragEvent("#tgt", "dragover", { dataTransfer, ...nearLeftEdge });

    assert
      .dom("#tgt")
      .hasClass("--drag-left", "the line stays on the side under the pointer");
    assert.dom("#tgt").doesNotHaveClass("--drag-right");

    await dragEvent("#tgt", "drop", { dataTransfer, ...nearLeftEdge });
    await dragEvent("#src", "dragend", { dataTransfer, ...centerOf("#src") });

    assert.deepEqual(
      drops,
      ["after"],
      "in a right-to-left row the left half comes after the midpoint in reading order"
    );
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

    // Asserted before the drop, so this pins down that the ancestor clears as
    // soon as it stops being deepest rather than only once the drop lands.
    assert
      .dom("#outer")
      .doesNotHaveClass(
        "--drag-inside",
        "moving onto the child clears the parent indicator immediately"
      );

    await dragEvent("#inner", "drop", {
      dataTransfer,
      ...centerOf("#inner"),
    });
    await dragEvent("#src", "dragend", {
      dataTransfer,
      ...centerOf("#src"),
    });
  });

  test("target arg changes reach the registered closure", async function (assert) {
    // The modifier registers once and hands the library a closure over its
    // args, so a changed arg has to be read through that closure rather than
    // through a re-registration.
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
    // The service derives drag state from its own element monitor rather than
    // being told by the source. Looking it up registers that monitor before the
    // drag begins.
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
    // Consumers key per-drag caches on the `currentDrag` reference, so the
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

  module(
    "the discriminator is the primitive's, not the payload's",
    function () {
      test("a `type` key on the payload does not change what a target accepts", async function (assert) {
        const drops = [];
        const onDrop = ({ source }) => drops.push(source.type);
        // A domain object carrying its own `type` is the ordinary case: models
        // routinely have one, and the modifier's own docs pass `data=this.link`.
        const payload = { id: 1, type: "something-else" };

        await render(
          <template>
            <div
              id="src"
              {{dDragAndDropSource type="row" data=payload}}
            >src</div>
            <div id="tgt" {{dDragAndDropTarget accepts="row" onDrop=onDrop}}>
              tgt
            </div>
          </template>
        );

        await simulateDrag("#src", "#tgt", {
          dataTransfer: new DataTransfer(),
        });

        assert.deepEqual(
          drops,
          ["row"],
          "the declared type wins, so the target still matches and reports it"
        );
      });
    }
  );

  module("a torn-down source drops its deferred callbacks", function () {
    test("destroying the modifier before the runloop flushes cancels them", async function (assert) {
      const calls = [];
      const state = new (class {
        @tracked rendered = true;
      })();
      const onDragEnd = () => calls.push("dragEnd");
      const onDrop = () => calls.push("drop");

      await render(
        <template>
          {{#if state.rendered}}
            <div
              id="src"
              {{dDragAndDropSource
                type="row"
                onDragEnd=onDragEnd
                onDrop=onDrop
              }}
            >src</div>
          {{/if}}
          <div id="tgt" {{dDragAndDropTarget accepts="row"}}>tgt</div>
        </template>
      );

      const dataTransfer = new DataTransfer();
      await startDrag("#src", { dataTransfer });
      await dragOver("#tgt", { dataTransfer });

      // The source defers its consumer callbacks to the next task, so tearing
      // it down in between is what a route transition or a re-render dropping
      // the row does.
      dragEventNow("#tgt", "drop", { dataTransfer, ...centerOf("#tgt") });
      state.rendered = false;
      await settled();

      assert.deepEqual(
        calls,
        [],
        "a destroyed source runs no consumer callback against it"
      );
    });

    test("re-registering the modifier before the runloop flushes keeps them", async function (assert) {
      const calls = [];
      const state = new (class {
        @tracked disabled = false;
      })();
      const onDragEnd = () => calls.push("dragEnd");
      const onDrop = () => calls.push("drop");

      await render(
        <template>
          <div
            id="src"
            {{dDragAndDropSource
              type="row"
              disabled=state.disabled
              onDragEnd=onDragEnd
              onDrop=onDrop
            }}
          >src</div>
          <div id="tgt" {{dDragAndDropTarget accepts="row"}}>tgt</div>
        </template>
      );

      const dataTransfer = new DataTransfer();
      await startDrag("#src", { dataTransfer });
      await dragOver("#tgt", { dataTransfer });

      dragEventNow("#tgt", "drop", { dataTransfer, ...centerOf("#tgt") });
      // The consumer is still here — only the registration is being replaced,
      // which is what an arg bound to drag state does the moment the drag ends.
      // It still expects to be told how its own drag finished.
      state.disabled = true;
      await settled();

      assert.deepEqual(
        calls,
        ["dragEnd", "drop"],
        "a source that merely re-registered still reports the drop it was in the middle of"
      );
    });

    test("a source disabled mid-drag still reports how that drag ended", async function (assert) {
      const calls = [];
      const state = new (class {
        @tracked disabled = false;
      })();
      const onDragEnd = () => calls.push("dragEnd");
      const onDrop = () => calls.push("drop");

      await render(
        <template>
          <div
            id="src"
            {{dDragAndDropSource
              type="row"
              disabled=state.disabled
              onDragEnd=onDragEnd
              onDrop=onDrop
            }}
          >src</div>
          <div id="tgt" {{dDragAndDropTarget accepts="row"}}>tgt</div>
        </template>
      );

      const dataTransfer = new DataTransfer();
      await dragEvent("#src", "dragstart", {
        dataTransfer,
        ...centerOf("#src"),
      });
      await dragEvent("#tgt", "dragenter", {
        dataTransfer,
        ...centerOf("#tgt"),
      });

      // Disabled while the drag is still in flight, which a consumer binding
      // the arg to anything that changes mid-drag will do. The drag itself
      // carries on — the browser is holding it, not the page.
      state.disabled = true;
      await settled();

      await dragEvent("#tgt", "dragover", {
        dataTransfer,
        ...centerOf("#tgt"),
      });
      await dragEvent("#tgt", "drop", {
        dataTransfer,
        ...centerOf("#tgt"),
      });

      assert.deepEqual(
        calls,
        ["dragEnd", "drop"],
        "the consumer is still told how its drag finished, as it is promised for every drag"
      );
    });

    test("a source re-enabled mid-drag leaves only one registration behind", async function (assert) {
      // White-box: a duplicate registration is only visible through the
      // library's dev-only warning, so that is what is asserted on.
      const warn = sinon.stub(console, "warn");
      const state = new (class {
        @tracked disabled = false;
      })();

      await render(
        <template>
          <div
            id="src"
            {{dDragAndDropSource type="row" disabled=state.disabled}}
          >src</div>
          <div id="tgt" {{dDragAndDropTarget accepts="row"}}>tgt</div>
        </template>
      );

      const dataTransfer = new DataTransfer();
      await dragEvent("#src", "dragstart", {
        dataTransfer,
        ...centerOf("#src"),
      });

      // Disabled while the drag is live, which keeps the registration alive to
      // report the drop, then enabled again before that drop arrives. The one
      // being kept is taken back rather than joined by a replacement.
      state.disabled = true;
      await settled();
      state.disabled = false;
      await settled();

      const duplicate = warn
        .getCalls()
        .some((call) =>
          String(call.args[0]).includes("already registered a `draggable`")
        );

      assert.false(
        duplicate,
        "the element carries one registration, not two competing for the same drag"
      );
    });

    test("a detached registration keeps its scheduled dispatch and reports it outstanding until it fires", async function (assert) {
      const calls = [];
      const args = {
        type: "row",
        onDragEnd: () => calls.push("dragEnd"),
        onDrop: () => calls.push("drop"),
      };

      await render(
        <template>
          <div id="src">src</div>
          <div id="tgt" {{dDragAndDropTarget accepts="row"}}>tgt</div>
        </template>
      );

      const release = registerDragAndDropSource(find("#src"), () => args);

      const dataTransfer = new DataTransfer();
      await startDrag("#src", { dataTransfer });
      await dragOver("#tgt", { dataTransfer });

      dragEventNow("#tgt", "drop", { dataTransfer, ...centerOf("#tgt") });

      const work = release({ cancelPending: false });

      assert.true(
        work.outstanding(),
        "a dispatch is still scheduled, so a holder has to keep it"
      );

      // The drag has already finished, so there is no registration left to take
      // back; the consumer is still there and is still owed the end of it.
      assert.strictEqual(
        work.reclaim(),
        null,
        "a finished drag leaves nothing to reclaim"
      );
      await settled();

      assert.deepEqual(
        calls,
        ["dragEnd", "drop"],
        "being replaced does not cost the consumer the drag it had already completed"
      );
      assert.false(
        work.outstanding(),
        "and once it has fired the work reports itself finished, so a holder can let go"
      );
    });

    test("abandoning a detached source drops the callbacks it still owes", async function (assert) {
      const calls = [];
      const args = {
        type: "row",
        onDragEnd: () => calls.push("dragEnd"),
        onDrop: () => calls.push("drop"),
      };

      await render(
        <template>
          <div id="src">src</div>
          <div id="tgt" {{dDragAndDropTarget accepts="row"}}>tgt</div>
        </template>
      );

      const release = registerDragAndDropSource(find("#src"), () => args);

      const dataTransfer = new DataTransfer();
      await startDrag("#src", { dataTransfer });
      await dragOver("#tgt", { dataTransfer });

      dragEventNow("#tgt", "drop", { dataTransfer, ...centerOf("#tgt") });

      // Detaching without cancelling hands the outstanding work back, because
      // this closure was the only thing that could still reach it.
      const work = release({ cancelPending: false });
      assert.strictEqual(
        typeof work?.abandon,
        "function",
        "keeping the dispatch hands back a way to reach it"
      );

      // The consumer itself is going away, which is the one reason to take the
      // dispatch back.
      work.abandon();
      await settled();

      assert.deepEqual(
        calls,
        [],
        "a consumer that is gone is not called for the drag it completed"
      );
    });

    test("a source disabled and re-enabled mid-drag still reports how that drag ended", async function (assert) {
      const calls = [];
      const state = new (class {
        @tracked disabled = false;
      })();
      const onDragEnd = () => calls.push("dragEnd");
      const onDrop = () => calls.push("drop");

      await render(
        <template>
          <div
            id="src"
            {{dDragAndDropSource
              type="row"
              disabled=state.disabled
              onDragEnd=onDragEnd
              onDrop=onDrop
            }}
          >src</div>
          <div id="tgt" {{dDragAndDropTarget accepts="row"}}>tgt</div>
        </template>
      );

      const dataTransfer = new DataTransfer();
      await dragEvent("#src", "dragstart", {
        dataTransfer,
        ...centerOf("#src"),
      });
      await dragEvent("#tgt", "dragenter", {
        dataTransfer,
        ...centerOf("#tgt"),
      });

      // Detached mid-drag, then replaced before the drop. Whichever registration
      // ends up holding the element has to be the one that reports, because the
      // consumer is promised the end of every drag it started.
      state.disabled = true;
      await settled();
      state.disabled = false;
      await settled();

      assert
        .dom("#src")
        .hasClass(
          "--dragging",
          "the drag in flight keeps its mark across the disable and re-enable"
        );

      await dragEvent("#tgt", "dragover", {
        dataTransfer,
        ...centerOf("#tgt"),
      });
      await dragEvent("#tgt", "drop", { dataTransfer, ...centerOf("#tgt") });

      assert.deepEqual(
        calls,
        ["dragEnd", "drop"],
        "replacing the registration mid-drag does not cost the consumer the end of it"
      );
    });

    test("a source whose handle changes identity mid-drag still reports how that drag ended", async function (assert) {
      const calls = [];
      const state = new (class {
        @tracked useSecondHandle = false;
        @tracked dragHandle;
        captureHandle = (element) => (this.dragHandle = element);
        onDragEnd = () => calls.push("dragEnd");
        onDrop = () => calls.push("drop");
      })();

      await render(
        <template>
          <div
            id="src"
            {{dDragAndDropSource
              type="row"
              dragHandle=state.dragHandle
              onDragEnd=state.onDragEnd
              onDrop=state.onDrop
            }}
          >
            {{#if state.useSecondHandle}}
              <button
                id="second-handle"
                type="button"
                {{didInsert state.captureHandle}}
              >second</button>
            {{else}}
              <button
                id="first-handle"
                type="button"
                {{didInsert state.captureHandle}}
              >first</button>
            {{/if}}
          </div>
          <div id="tgt" {{dDragAndDropTarget accepts="row"}}>tgt</div>
        </template>
      );

      const dataTransfer = new DataTransfer();
      // The drag begins on the handle the live registration sits on.
      await dragEvent("#first-handle", "dragstart", {
        dataTransfer,
        ...centerOf("#src"),
      });
      await dragEvent("#tgt", "dragenter", {
        dataTransfer,
        ...centerOf("#tgt"),
      });
      await dragEvent("#tgt", "dragover", {
        dataTransfer,
        ...centerOf("#tgt"),
      });

      // The handle is re-rendered mid-drag, replacing the registration while
      // the drag it started is still in flight. The library dispatches the
      // drag's end by looking the ORIGINAL handle up, so the replaced
      // registration must stay reachable until then.
      state.useSecondHandle = true;
      await settled();

      assert
        .dom("#src")
        .hasClass("--dragging", "the drag in flight keeps its mark");

      await dragEvent("#tgt", "drop", { dataTransfer, ...centerOf("#tgt") });
      await settled();

      assert.deepEqual(
        calls,
        ["dragEnd", "drop"],
        "the swap does not cost the consumer the end of its drag"
      );
    });

    test("a source disabled mid-drag and then destroyed drops its callbacks", async function (assert) {
      const calls = [];
      const state = new (class {
        @tracked disabled = false;
        @tracked rendered = true;
      })();
      const onDragEnd = () => calls.push("dragEnd");
      const onDrop = () => calls.push("drop");

      await render(
        <template>
          {{#if state.rendered}}
            <div
              id="src"
              {{dDragAndDropSource
                type="row"
                disabled=state.disabled
                onDragEnd=onDragEnd
                onDrop=onDrop
              }}
            >src</div>
          {{/if}}
          <div id="tgt" {{dDragAndDropTarget accepts="row"}}>tgt</div>
        </template>
      );

      const dataTransfer = new DataTransfer();
      await startDrag("#src", { dataTransfer });
      await dragOver("#tgt", { dataTransfer });

      // Detached, but kept alive to report the drag it is in the middle of.
      state.disabled = true;
      await settled();

      // The drop schedules the consumer callbacks, and the row goes away before
      // the runloop flushes them. Whatever is still holding that dispatch has to
      // be reachable from here, or nothing can call it off.
      dragEventNow("#tgt", "drop", { dataTransfer, ...centerOf("#tgt") });
      state.rendered = false;
      await settled();

      assert.deepEqual(
        calls,
        [],
        "a destroyed consumer runs no callback for the drag its registration was keeping"
      );
    });

    test("a consumer that throws does not strand the registration", async function (assert) {
      let thrown = 0;
      setupOnerror(() => thrown++);

      const state = new (class {
        @tracked disabled = false;
      })();
      const onDragEnd = () => {
        throw new Error("consumer blew up");
      };

      await render(
        <template>
          <div
            id="src"
            {{dDragAndDropSource
              type="row"
              disabled=state.disabled
              onDragEnd=onDragEnd
            }}
          >src</div>
          <div id="tgt" {{dDragAndDropTarget accepts="row"}}>tgt</div>
        </template>
      );

      const dataTransfer = new DataTransfer();
      await dragEvent("#src", "dragstart", {
        dataTransfer,
        ...centerOf("#src"),
      });
      await dragEvent("#tgt", "dragenter", {
        dataTransfer,
        ...centerOf("#tgt"),
      });

      // Detached mid-drag, so the teardown is waiting on the drop that is about
      // to dispatch into a consumer that throws.
      state.disabled = true;
      await settled();

      await dragEvent("#tgt", "dragover", {
        dataTransfer,
        ...centerOf("#tgt"),
      });
      await dragEvent("#tgt", "drop", { dataTransfer, ...centerOf("#tgt") });

      assert.strictEqual(thrown, 1, "the consumer's error is not swallowed");
      assert
        .dom("#src")
        .doesNotHaveAttribute(
          "data-drag-source",
          "and the registration is still torn down, rather than left on the element for good"
        );
    });
  });

  module("a drag held over nothing", function () {
    /**
     * Dispatches a drag event and hands the event back, which `triggerEvent`
     * cannot: what is being asserted is whether something claimed the event.
     *
     * `dataTransfer.dropEffect` would be the more direct reading, and it is not
     * available — a synthetic drag leaves it at `"none"` however it is set, even
     * over a target that asked for `"copy"`. `defaultPrevented` is the half that
     * carries the meaning anyway: it is what tells the browser the drag was
     * handled here, and the cursor follows from it.
     */
    async function dragOverAndReturnEvent(selector, dataTransfer) {
      const event = new DragEvent("dragover", {
        bubbles: true,
        cancelable: true,
        dataTransfer,
        ...centerOf(selector),
      });
      find(selector).dispatchEvent(event);
      await new Promise((resolve) => requestAnimationFrame(resolve));
      return event;
    }

    test("a sourced drag claims the space no target wants", async function (assert) {
      await render(
        <template>
          <div id="row" {{dDragAndDropSource type="row"}}>row</div>
          <div id="nowhere">not a drop target</div>
        </template>
      );

      const dataTransfer = new DataTransfer();
      await dragEvent("#row", "dragstart", {
        dataTransfer,
        ...centerOf("#row"),
      });

      const event = await dragOverAndReturnEvent("#nowhere", dataTransfer);

      assert.true(
        event.defaultPrevented,
        "the drag answers for itself over dead space, so the browser stops offering to copy something it has no way to take"
      );
    });
  });

  module("what a drag permits", function () {
    /**
     * A real `DataTransfer` whose `effectAllowed` keeps what is written to it.
     *
     * The native property is a no-op here — its setter requires a drag data
     * store in a mode only a browser-driven drag puts it in, so a synthetic
     * event silently discards every write, the test's own included. An own
     * property shadows the accessor and leaves the rest of the object real,
     * which makes what the source declares readable at all.
     */
    function recordingTransfer(effectAllowed = "none") {
      const dataTransfer = new DataTransfer();
      Object.defineProperty(dataTransfer, "effectAllowed", {
        value: effectAllowed,
        writable: true,
        configurable: true,
      });
      return dataTransfer;
    }

    test("a sourced drag permits a move, and nothing else", async function (assert) {
      await render(
        <template>
          <div id="row" {{dDragAndDropSource type="row"}}>row</div>
        </template>
      );

      const dataTransfer = recordingTransfer();
      await dragEvent("#row", "dragstart", {
        dataTransfer,
        ...centerOf("#row"),
      });

      assert.strictEqual(
        dataTransfer.effectAllowed,
        "move",
        "the drag says what it permits, so the pointer stops carrying the browser's standing offer to copy"
      );
    });

    test("a source can permit a copy as well", async function (assert) {
      await render(
        <template>
          <div
            id="row"
            {{dDragAndDropSource type="row" effectAllowed="copyMove"}}
          >row</div>
        </template>
      );

      const dataTransfer = recordingTransfer();
      await dragEvent("#row", "dragstart", {
        dataTransfer,
        ...centerOf("#row"),
      });

      assert.strictEqual(
        dataTransfer.effectAllowed,
        "copyMove",
        "a source whose drop duplicates rather than relocates keeps the copy available to its targets"
      );
    });

    test("the innermost source is the one that answers", async function (assert) {
      await render(
        <template>
          <div id="outer" {{dDragAndDropSource type="outer"}}>
            <div
              id="inner"
              {{dDragAndDropSource type="inner" effectAllowed="copyMove"}}
            >inner</div>
          </div>
        </template>
      );

      const dataTransfer = recordingTransfer();
      await dragEvent("#inner", "dragstart", {
        dataTransfer,
        ...centerOf("#inner"),
      });

      assert.strictEqual(
        dataTransfer.effectAllowed,
        "copyMove",
        "a drag begun on a nested source passes through its ancestor on the way out, which must not answer over it"
      );
    });

    test("a source still registered keeps answering after a sibling detaches", async function (assert) {
      const state = new (class {
        @tracked disabled = false;
      })();

      await render(
        <template>
          <div
            id="going"
            {{dDragAndDropSource type="going" disabled=state.disabled}}
          >going</div>
          <div id="staying" {{dDragAndDropSource type="staying"}}>staying</div>
        </template>
      );

      state.disabled = true;
      await settled();

      const dataTransfer = recordingTransfer();
      await dragEvent("#staying", "dragstart", {
        dataTransfer,
        ...centerOf("#staying"),
      });

      assert.strictEqual(
        dataTransfer.effectAllowed,
        "move",
        "one source going away takes only its own share of the shared listener"
      );
    });

    test("the last source to go takes the shared listener with it", async function (assert) {
      // White-box, because the only thing a leak costs is an idle listener and
      // a map entry per registration — nothing a drag can observe.
      const state = new (class {
        @tracked disabled = false;
      })();

      await render(
        <template>
          <div
            id="row"
            {{dDragAndDropSource type="row" disabled=state.disabled}}
          >row</div>
        </template>
      );

      const released = sinon.spy(window, "removeEventListener");
      state.disabled = true;
      await settled();

      assert.true(
        released.calledWith("dragstart", sinon.match.func, { capture: true }),
        "nothing stays bound to a page with no drag sources left on it"
      );
    });

    module("registration ownership across a handle change", function () {
      test("a handle swapped mid-drag leaves the row registered and declaring its effect", async function (assert) {
        const state = new (class {
          @tracked useSecondHandle = false;
          @tracked dragHandle;
          captureHandle = (element) => (this.dragHandle = element);
        })();

        await render(
          <template>
            <div
              id="src"
              {{dDragAndDropSource type="row" dragHandle=state.dragHandle}}
            >
              {{#if state.useSecondHandle}}
                <button
                  id="second-handle"
                  type="button"
                  {{didInsert state.captureHandle}}
                >second</button>
              {{else}}
                <button
                  id="first-handle"
                  type="button"
                  {{didInsert state.captureHandle}}
                >first</button>
              {{/if}}
            </div>
            <div id="tgt" {{dDragAndDropTarget accepts="row"}}>tgt</div>
          </template>
        );

        const dataTransfer = new DataTransfer();
        await dragEvent("#first-handle", "dragstart", {
          dataTransfer,
          ...centerOf("#src"),
        });
        await dragEvent("#tgt", "dragenter", {
          dataTransfer,
          ...centerOf("#tgt"),
        });

        state.useSecondHandle = true;
        await settled();

        await dragEvent("#tgt", "drop", { dataTransfer, ...centerOf("#tgt") });
        await dragEvent("#src", "dragend", {
          dataTransfer,
          ...centerOf("#src"),
        });
        await settled();

        assert
          .dom("#src")
          .hasAttribute(
            "data-drag-source",
            "",
            "the replaced registration's teardown does not strip the mark the live one owns"
          );

        const second = recordingTransfer();
        await dragEvent("#second-handle", "dragstart", {
          dataTransfer: second,
          ...centerOf("#src"),
        });
        assert.strictEqual(
          second.effectAllowed,
          "move",
          "and the live registration still declares what a drag from the new handle permits"
        );
        await dragEvent("#src", "dragend", {
          dataTransfer: second,
          ...centerOf("#src"),
        });

        const released = sinon.spy(window, "removeEventListener");
        await clearRender();
        assert.true(
          released.calledWith("dragstart", sinon.match.func, { capture: true }),
          "destroying the source unbinds the shared listener: the swap left no phantom registration counted"
        );
      });

      test("a handle swapped mid-drag and then disabled keeps the row marked until the drag it started ends", async function (assert) {
        const state = new (class {
          @tracked useSecondHandle = false;
          @tracked disabled = false;
          @tracked dragHandle;
          captureHandle = (element) => (this.dragHandle = element);
        })();

        await render(
          <template>
            <div
              id="src"
              {{dDragAndDropSource
                type="row"
                dragHandle=state.dragHandle
                disabled=state.disabled
              }}
            >
              {{#if state.useSecondHandle}}
                <button
                  id="second-handle"
                  type="button"
                  {{didInsert state.captureHandle}}
                >second</button>
              {{else}}
                <button
                  id="first-handle"
                  type="button"
                  {{didInsert state.captureHandle}}
                >first</button>
              {{/if}}
            </div>
            <div id="tgt" {{dDragAndDropTarget accepts="row"}}>tgt</div>
          </template>
        );

        const dataTransfer = new DataTransfer();
        await dragEvent("#first-handle", "dragstart", {
          dataTransfer,
          ...centerOf("#src"),
        });
        await dragEvent("#tgt", "dragenter", {
          dataTransfer,
          ...centerOf("#tgt"),
        });

        state.useSecondHandle = true;
        await settled();
        state.disabled = true;
        await settled();

        assert
          .dom("#src")
          .hasAttribute(
            "data-drag-source",
            "",
            "the first handle's drag is still in flight, so the row stays a registered source"
          );
        assert
          .dom("#src")
          .hasClass(
            "--dragging",
            "and disabling the replacement does not strip the mark of the drag it never owned"
          );

        await dragEvent("#tgt", "drop", { dataTransfer, ...centerOf("#tgt") });
        await dragEvent("#src", "dragend", {
          dataTransfer,
          ...centerOf("#src"),
        });
        await settled();

        assert
          .dom("#src")
          .doesNotHaveAttribute(
            "data-drag-source",
            "once that drag ends nothing is registered any more"
          );
      });

      test("a handle cycled away, back and away again mid-drag still reports how that drag ended", async function (assert) {
        const calls = [];
        const state = new (class {
          @tracked dragHandle;
          handles = {};
          captureHandle = (element) => {
            this.handles[element.id] = element;
            this.dragHandle ??= element;
          };
          onDragEnd = () => calls.push("dragEnd");
          onDrop = () => calls.push("drop");
        })();

        await render(
          <template>
            <div
              id="src"
              {{dDragAndDropSource
                type="row"
                dragHandle=state.dragHandle
                onDragEnd=state.onDragEnd
                onDrop=state.onDrop
              }}
            >
              <button
                id="handle-a"
                type="button"
                {{didInsert state.captureHandle}}
              >a</button>
              <button
                id="handle-b"
                type="button"
                {{didInsert state.captureHandle}}
              >b</button>
            </div>
            <div id="tgt" {{dDragAndDropTarget accepts="row"}}>tgt</div>
          </template>
        );

        assert
          .dom("#handle-a")
          .hasAttribute("draggable", "true", "the drag starts on handle a");

        const dataTransfer = new DataTransfer();
        await dragEvent("#handle-a", "dragstart", {
          dataTransfer,
          ...centerOf("#src"),
        });
        await dragEvent("#tgt", "dragenter", {
          dataTransfer,
          ...centerOf("#tgt"),
        });
        await dragEvent("#tgt", "dragover", {
          dataTransfer,
          ...centerOf("#tgt"),
        });

        // The library dispatches the drag's end to whatever is registered on
        // handle a at drop time, so a has to stay registered through every swap,
        // including the one that brings it back.
        state.dragHandle = state.handles["handle-b"];
        await settled();
        state.dragHandle = state.handles["handle-a"];
        await settled();
        state.dragHandle = state.handles["handle-b"];
        await settled();

        assert
          .dom("#src")
          .hasClass("--dragging", "the drag in flight keeps its mark");

        await dragEvent("#tgt", "drop", { dataTransfer, ...centerOf("#tgt") });
        await settled();

        assert.deepEqual(
          calls,
          ["dragEnd", "drop"],
          "cycling the handle does not cost the consumer the end of its drag"
        );
      });

      test("a handle swapped in the same task as dragstart still reports the drag", async function (assert) {
        const calls = [];
        const state = new (class {
          @tracked dragHandle;
          handles = {};
          captureHandle = (element) => {
            this.handles[element.id] = element;
            this.dragHandle ??= element;
          };
          onDragStart = () => calls.push("start");
          onDragEnd = () => calls.push("dragEnd");
          onDrop = () => calls.push("drop");
        })();

        await render(
          <template>
            <div
              id="src"
              {{dDragAndDropSource
                type="row"
                dragHandle=state.dragHandle
                onDragStart=state.onDragStart
                onDragEnd=state.onDragEnd
                onDrop=state.onDrop
              }}
            >
              <button
                id="handle-a"
                type="button"
                {{didInsert state.captureHandle}}
              >a</button>
              <button
                id="handle-b"
                type="button"
                {{didInsert state.captureHandle}}
              >b</button>
            </div>
            <div id="tgt" {{dDragAndDropTarget accepts="row"}}>tgt</div>
          </template>
        );

        // The library defers the drag-start callback by a frame. A swap landing
        // in that window must still see a drag in flight, or the registration
        // that has to receive the deferred callbacks is torn down at once.
        const dataTransfer = new DataTransfer();
        dragEventNow("#handle-a", "dragstart", {
          dataTransfer,
          ...centerOf("#src"),
        });
        state.dragHandle = state.handles["handle-b"];
        await settled();

        await dragEvent("#tgt", "dragenter", {
          dataTransfer,
          ...centerOf("#tgt"),
        });
        await dragEvent("#tgt", "dragover", {
          dataTransfer,
          ...centerOf("#tgt"),
        });
        assert
          .dom("#src")
          .hasClass("--dragging", "the drag in flight is marked");

        await dragEvent("#tgt", "drop", { dataTransfer, ...centerOf("#tgt") });
        await settled();

        assert.deepEqual(
          calls,
          ["start", "dragEnd", "drop"],
          "the swap does not orphan the drag"
        );
      });

      test("a natively draggable child of a source row is not answered", async function (assert) {
        await render(
          <template>
            <div id="row" {{dDragAndDropSource type="row"}}>
              row
              <a id="link" href="/somewhere">link</a>
            </div>
          </template>
        );

        // The anchor is draggable on its own, so the browser targets it and the
        // library never claims the drag; the source must not speak for it either.
        const dataTransfer = recordingTransfer();
        await dragEvent("#link", "dragstart", {
          dataTransfer,
          ...centerOf("#link"),
        });

        assert.strictEqual(
          dataTransfer.effectAllowed,
          "none",
          "a drag the primitive did not start keeps whatever the browser gave it"
        );
      });
    });
  });

  module("drag previews", function () {
    test("the default preview of a handled row keeps the grab point", async function (assert) {
      const state = new (class {
        @tracked dragHandle;
        captureHandle = (element) => (this.dragHandle = element);
      })();

      await render(
        <template>
          <div
            id="src"
            style="width: 300px; height: 40px; display: flex; justify-content: flex-end"
            {{dDragAndDropSource type="row" dragHandle=state.dragHandle}}
          >
            <button
              id="grip"
              type="button"
              style="width: 30px"
              {{didInsert state.captureHandle}}
            >grip</button>
          </div>
        </template>
      );

      const dataTransfer = new DataTransfer();
      const setDragImage = sinon.spy(dataTransfer, "setDragImage");
      const rowRect = find("#src").getBoundingClientRect();
      const grab = centerOf("#grip");

      await dragEvent("#grip", "dragstart", { dataTransfer, ...grab });

      assert.true(setDragImage.calledOnce, "the row stands in for the grip");
      const [image, x, y] = setDragImage.firstCall.args;
      assert.strictEqual(image, find("#src"), "the photograph is the row");
      assert.strictEqual(
        Math.round(x),
        Math.round(grab.clientX - rowRect.left),
        "the hotspot is where the user grabbed, measured from the row's left"
      );
      assert.strictEqual(
        Math.round(y),
        Math.round(grab.clientY - rowRect.top),
        "and from its top, so the picture does not jump under the pointer"
      );

      await dragEvent("#src", "dragend", { dataTransfer, ...grab });
    });

    test("an Element preview that is not the row is photographed at its own origin", async function (assert) {
      const state = new (class {
        @tracked preview;
        capturePreview = (element) => (this.preview = element);
      })();

      await render(
        <template>
          <div
            id="src"
            {{dDragAndDropSource type="row" dragPreview=state.preview}}
          >src</div>
          <div id="ghost" {{didInsert state.capturePreview}}>ghost</div>
        </template>
      );

      const dataTransfer = new DataTransfer();
      const setDragImage = sinon.spy(dataTransfer, "setDragImage");
      await dragEvent("#src", "dragstart", {
        dataTransfer,
        ...centerOf("#src"),
      });

      assert.true(
        setDragImage.calledOnceWithExactly(find("#ghost"), 0, 0),
        "a foreign preview keeps the top-left hotspot"
      );

      await dragEvent("#src", "dragend", { dataTransfer, ...centerOf("#src") });
    });

    test("getInitialData supplies the payload and cannot override the type", async function (assert) {
      const sources = [];
      const recordDrop = ({ source }) => sources.push(source);
      const describe = () => ({ id: 7, type: "impostor" });

      await render(
        <template>
          <div
            id="src"
            {{dDragAndDropSource type="row" getInitialData=describe}}
          >src</div>
          <div
            id="tgt"
            {{dDragAndDropTarget accepts="row" onDrop=recordDrop}}
          >tgt</div>
        </template>
      );

      await simulateDrag("#src", "#tgt", { dataTransfer: new DataTransfer() });

      assert.deepEqual(
        sources.map(({ type, data }) => ({ type, data })),
        [{ type: "row", data: { id: 7, type: "row" } }],
        "the payload comes from getInitialData and the primitive's type is stamped over the payload's own"
      );
    });
  });

  module("lifecycle callbacks stay paired", function () {
    test("an ancestor that never received an enter receives no leave", async function (assert) {
      const events = [];
      const onOuterEnter = () => events.push("outer:enter");
      const onOuterLeave = () => events.push("outer:leave");
      // The deepest target is instrumented too, as this test's positive control:
      // without it, an implementation that dispatched no lifecycle callback at
      // all would satisfy the assertion below just as well as a correct one.
      const onInnerEnter = () => events.push("inner:enter");
      const onInnerLeave = () => events.push("inner:leave");

      await render(
        <template>
          <div id="src" {{dDragAndDropSource type="row"}}>src</div>
          <div
            id="outer"
            style="height: 100px"
            {{dDragAndDropTarget
              accepts="row"
              position="inside"
              onDragEnter=onOuterEnter
              onDragLeave=onOuterLeave
            }}
          >
            outer
            <div
              id="inner"
              {{dDragAndDropTarget
                accepts="row"
                position="inside"
                onDragEnter=onInnerEnter
                onDragLeave=onInnerLeave
              }}
            >inner</div>
          </div>
          <div id="away" {{dDragAndDropTarget accepts="row"}}>away</div>
        </template>
      );

      const dataTransfer = new DataTransfer();
      await startDrag("#src", { dataTransfer });
      // Straight onto the child, so the ancestor is in the stack but never the
      // deepest and so never forwards an enter.
      await dragOver("#inner", { dataTransfer });
      await dragOver("#away", { dataTransfer });
      await dragEvent("#src", "dragend", { dataTransfer, ...centerOf("#src") });

      assert.deepEqual(
        events,
        ["inner:enter", "inner:leave"],
        "the deepest target is entered and left as a pair, and the ancestor that was never entered is never left"
      );
    });

    test("a target that becomes deepest without a fresh enter is entered and left", async function (assert) {
      const events = [];
      let drags = 0;

      const onOuterEnter = () => events.push("outer:enter");
      const onOuterDrag = () => drags++;
      const onOuterLeave = () => events.push("outer:leave");

      await render(
        <template>
          <div id="src" {{dDragAndDropSource type="row"}}>src</div>
          <div
            id="outer"
            style="height: 100px"
            {{dDragAndDropTarget
              accepts="row"
              position="inside"
              onDragEnter=onOuterEnter
              onDrag=onOuterDrag
              onDragLeave=onOuterLeave
            }}
          >
            outer
            <div
              id="inner"
              {{dDragAndDropTarget accepts="row" position="inside"}}
            >inner</div>
          </div>
          <div id="away" {{dDragAndDropTarget accepts="row"}}>away</div>
        </template>
      );

      const dataTransfer = new DataTransfer();
      const outerRect = find("#outer").getBoundingClientRect();

      await dragEvent("#src", "dragstart", {
        dataTransfer,
        ...centerOf("#src"),
      });

      // Onto the child first, so the ancestor joins the hierarchy while the
      // child is deepest and its own enter is swallowed.
      await dragEvent("#inner", "dragenter", {
        dataTransfer,
        ...centerOf("#inner"),
      });
      await dragEvent("#inner", "dragover", {
        dataTransfer,
        ...centerOf("#inner"),
      });

      // Back onto the ancestor's own area. It becomes deepest without a fresh
      // enter, because it never left the hierarchy.
      await dragEvent("#outer", "dragover", {
        dataTransfer,
        clientX: outerRect.left + 5,
        clientY: outerRect.top + 5,
      });

      await dragEvent("#away", "dragenter", {
        dataTransfer,
        ...centerOf("#away"),
      });
      await dragEvent("#away", "dragover", {
        dataTransfer,
        ...centerOf("#away"),
      });
      await dragEvent("#src", "dragend", { dataTransfer, ...centerOf("#src") });

      assert.true(
        drags > 0,
        "the ancestor was told about the drag once it was the deepest target"
      );
      assert.deepEqual(
        events,
        ["outer:enter", "outer:leave"],
        "so it is entered when it takes over and left when it gives up, rather than being told only about the middle"
      );
    });

    test("an ancestor superseded by a child is left before the drop lands", async function (assert) {
      const events = [];
      const onOuterEnter = () => events.push("outer:enter");
      const onOuterLeave = () => events.push("outer:leave");
      // Recording the drop pins the ordering as well as the pairing: the
      // ancestor has to be left when the child takes over, not once the drag is
      // already over.
      const onInnerDrop = () => events.push("inner:drop");

      await render(
        <template>
          <div id="src" {{dDragAndDropSource type="row"}}>src</div>
          <div
            id="outer"
            style="height: 100px"
            {{dDragAndDropTarget
              accepts="row"
              position="inside"
              onDragEnter=onOuterEnter
              onDragLeave=onOuterLeave
            }}
          >
            outer
            <div
              id="inner"
              {{dDragAndDropTarget
                accepts="row"
                position="inside"
                onDrop=onInnerDrop
              }}
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

      // The ancestor's own area first, so it is genuinely entered.
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

      // Then onto the child. The ancestor stays in the hierarchy, so no leave
      // arrives from the library and the target has to synthesise one.
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
      await dragEvent("#src", "dragend", { dataTransfer, ...centerOf("#src") });

      assert.deepEqual(
        events,
        ["outer:enter", "outer:leave", "inner:drop"],
        "the ancestor is left as soon as the child takes over, so a drop never lands with its enter still open"
      );
    });

    test("a second drag over the same target is entered again", async function (assert) {
      const events = [];
      const onEnter = () => events.push("enter");
      const onLeave = () => events.push("leave");
      const onDrop = () => events.push("drop");

      await render(
        <template>
          <div id="src" {{dDragAndDropSource type="row"}}>src</div>
          <div
            id="target"
            {{dDragAndDropTarget
              accepts="row"
              position="inside"
              onDragEnter=onEnter
              onDragLeave=onLeave
              onDrop=onDrop
            }}
          >target</div>
          <div id="away" {{dDragAndDropTarget accepts="row"}}>away</div>
        </template>
      );

      const firstTransfer = new DataTransfer();
      await startDrag("#src", { dataTransfer: firstTransfer });
      await dragOver("#target", { dataTransfer: firstTransfer });
      // A drop closes the enter without reporting a leave, so the target has to
      // forget it was entered or the next drag's enter is swallowed.
      await dragEvent("#target", "drop", {
        dataTransfer: firstTransfer,
        ...centerOf("#target"),
      });
      await dragEvent("#src", "dragend", {
        dataTransfer: firstTransfer,
        ...centerOf("#src"),
      });

      const secondTransfer = new DataTransfer();
      await startDrag("#src", { dataTransfer: secondTransfer });
      await dragOver("#target", { dataTransfer: secondTransfer });
      await dragOver("#away", { dataTransfer: secondTransfer });
      await dragEvent("#src", "dragend", {
        dataTransfer: secondTransfer,
        ...centerOf("#src"),
      });

      assert.deepEqual(
        events,
        ["enter", "drop", "enter", "leave"],
        "each drag gets its own enter, and the second one is still paired with a leave"
      );
    });
  });

  /**
   * The library tells a target about a hierarchy change synchronously, but only
   * throttles the drag update that follows to a frame. A drop cancels that frame,
   * so anything a target learns only from the drag update is lost to a fast release.
   */
  module("a hierarchy change is observed in the same frame", function () {
    test("an ancestor superseded by a child is left in the same frame, before the drop", async function (assert) {
      const events = [];
      const onOuterEnter = () => events.push("outer:enter");
      const onOuterLeave = () => events.push("outer:leave");
      const onInnerDrop = () => events.push("inner:drop");

      await render(
        <template>
          <div id="src" {{dDragAndDropSource type="row"}}>src</div>
          <div
            id="outer"
            style="height: 100px"
            {{dDragAndDropTarget
              accepts="row"
              position="inside"
              onDragEnter=onOuterEnter
              onDragLeave=onOuterLeave
            }}
          >
            outer
            <div
              id="inner"
              {{dDragAndDropTarget
                accepts="row"
                position="inside"
                onDrop=onInnerDrop
              }}
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
        .hasClass("--drag-inside", "the ancestor is entered and lit");

      // The child takes over and the drop lands in the same task: no frame in
      // between for a throttled drag update to tell the ancestor anything.
      dragEventNow("#inner", "dragenter", {
        dataTransfer,
        ...centerOf("#inner"),
      });

      assert.deepEqual(
        events,
        ["outer:enter", "outer:leave"],
        "the ancestor is left the moment the child takes over, without waiting for a frame"
      );
      assert
        .dom("#outer")
        .doesNotHaveClass(
          "--drag-inside",
          "and its indicator goes with the role"
        );

      dragEventNow("#inner", "drop", { dataTransfer, ...centerOf("#inner") });
      await settled();
      await dragEvent("#src", "dragend", { dataTransfer, ...centerOf("#src") });

      assert.deepEqual(
        events,
        ["outer:enter", "outer:leave", "inner:drop"],
        "the drop lands on the child with the ancestor already left"
      );
    });

    test("flipping indicator off mid-hover clears the class already shown", async function (assert) {
      const state = new (class {
        @tracked indicator = true;
      })();

      await render(
        <template>
          <div id="src" {{dDragAndDropSource type="row"}}>src</div>
          <div
            id="tgt"
            {{dDragAndDropTarget
              accepts="row"
              position="before"
              indicator=state.indicator
            }}
          >tgt</div>
        </template>
      );

      const dataTransfer = new DataTransfer();
      await startDrag("#src", { dataTransfer });
      await dragOver("#tgt", { dataTransfer });

      assert.dom("#tgt").hasClass("--drag-above", "lit while indicating");

      state.indicator = false;
      await settled();
      await dragEvent("#tgt", "dragover", {
        dataTransfer,
        ...centerOf("#tgt"),
      });

      assert
        .dom("#tgt")
        .doesNotHaveClass(
          "--drag-above",
          "turning the indicator off clears what was already painted, not only what comes next"
        );
    });

    test("a drop clears the indicator of the target it lands on", async function (assert) {
      await render(
        <template>
          <div id="src" {{dDragAndDropSource type="row"}}>src</div>
          <div
            id="tgt"
            {{dDragAndDropTarget accepts="row" position="before"}}
          >tgt</div>
        </template>
      );

      const dataTransfer = new DataTransfer();
      await startDrag("#src", { dataTransfer });
      await dragOver("#tgt", { dataTransfer });

      assert.dom("#tgt").hasClass("--drag-above", "lit while hovered");

      // The drop follows without a frame, so the throttled drag update it would
      // have cancelled is not what clears the class.
      dragEventNow("#tgt", "drop", { dataTransfer, ...centerOf("#tgt") });
      await settled();
      await dragEvent("#src", "dragend", { dataTransfer, ...centerOf("#src") });

      assert
        .dom("#tgt")
        .doesNotHaveClass(
          "--drag-above",
          "the drop itself clears the indicator of the target it lands on"
        );
    });
  });

  /**
   * The library reaches its end-of-drag cleanup on the statement after it calls a
   * consumer, unguarded, so an escaping exception skips it and is reported as uncaught.
   */
  module("a consumer that throws cannot break the dispatch", function () {
    const blowUp = () => {
      throw new Error("consumer blew up");
    };

    test("a throwing target onDrop leaves the next drag able to run", async function (assert) {
      const reported = [];
      setupOnerror((error) => reported.push(error));

      // `setupOnerror` only sees the test-time raise. The production report is a
      // separate channel and would go unnoticed if it stopped firing.
      const notices = [];
      const collect = (event) => notices.push(event.detail.messageKey);
      document.addEventListener("discourse-error", collect);

      const ends = [];
      const recordEnd = () => ends.push("end");
      const laterDrops = [];
      const recordLaterDrop = () => laterDrops.push("drop");

      await render(
        <template>
          <div
            id="src"
            {{dDragAndDropSource type="row" onDragEnd=recordEnd}}
          >src</div>
          <div
            id="tgt"
            {{dDragAndDropTarget accepts="row" onDrop=blowUp}}
          >tgt</div>
          <div id="later-src" {{dDragAndDropSource type="row"}}>later src</div>
          <div
            id="later-tgt"
            {{dDragAndDropTarget accepts="row" onDrop=recordLaterDrop}}
          >later tgt</div>
        </template>
      );

      try {
        await simulateDrag("#src", "#tgt", {
          dataTransfer: new DataTransfer(),
        });

        assert.strictEqual(
          reported.length,
          1,
          "the error reaches the application rather than escaping as an uncaught one"
        );
        assert.deepEqual(
          notices,
          ["broken_drag_and_drop_alert"],
          "and is reported through the channel that reaches admins in production"
        );
        assert.deepEqual(
          ends,
          ["end"],
          "the source hears its drag end exactly once"
        );
        assert.false(
          this.owner.lookup("service:drag-and-drop").isDragging,
          "and the service stops reporting a drag in flight"
        );

        await simulateDrag("#later-src", "#later-tgt", {
          dataTransfer: new DataTransfer(),
        });

        assert.deepEqual(
          laterDrops,
          ["drop"],
          "so a later drag still reaches its own target"
        );
      } finally {
        document.removeEventListener("discourse-error", collect);
      }
    });

    test("a throwing monitor onDrop leaves the next drag able to run", async function (assert) {
      const reported = [];
      setupOnerror((error) => reported.push(error));

      const laterDrops = [];
      const recordLaterDrop = () => laterDrops.push("drop");
      const stopMonitoring = registerDragAndDropMonitor(() => ({
        onDrop: blowUp,
      }));

      try {
        await render(
          <template>
            <div id="src" {{dDragAndDropSource type="row"}}>src</div>
            <div
              id="tgt"
              {{dDragAndDropTarget accepts="row" onDrop=recordLaterDrop}}
            >tgt</div>
          </template>
        );

        // Abandoned rather than dropped, because that is the path where the
        // library has no later event to recover on.
        const abandoned = new DataTransfer();
        await dragEvent("#src", "dragstart", {
          dataTransfer: abandoned,
          ...centerOf("#src"),
        });
        await dragEvent("#src", "dragend", {
          dataTransfer: abandoned,
          ...centerOf("#src"),
        });

        await simulateDrag("#src", "#tgt", {
          dataTransfer: new DataTransfer(),
        });
      } finally {
        stopMonitoring();
      }

      assert.deepEqual(
        laterDrops,
        ["drop"],
        "a drag abandoned into a throwing monitor does not stop the next one"
      );
      assert.strictEqual(
        reported.length,
        2,
        "and both throws are reported, one per drag the global monitor saw"
      );
    });

    test("a throwing onDragEnd does not cost a landed drag its onDrop", async function (assert) {
      const reported = [];
      setupOnerror((error) => reported.push(error));

      const drops = [];
      const recordDrop = () => drops.push("drop");

      await render(
        <template>
          <div
            id="src"
            {{dDragAndDropSource type="row" onDragEnd=blowUp onDrop=recordDrop}}
          >src</div>
          <div id="tgt" {{dDragAndDropTarget accepts="row"}}>tgt</div>
        </template>
      );

      await simulateDrag("#src", "#tgt", {
        dataTransfer: new DataTransfer(),
      });

      assert.deepEqual(
        drops,
        ["drop"],
        "the drag landed, so the operation still runs even though the lifecycle callback threw"
      );
      assert.strictEqual(reported.length, 1, "and the throw is still reported");
    });

    test("a throwing canDrop refuses the drop instead of allowing it", async function (assert) {
      const reported = [];
      setupOnerror((error) => reported.push(error));

      const notices = [];
      const collect = (event) => notices.push(event.detail.messageKey);
      document.addEventListener("discourse-error", collect);

      const drops = [];
      const recordDrop = () => drops.push("drop");

      await render(
        <template>
          <div id="src" {{dDragAndDropSource type="row"}}>src</div>
          <div
            id="tgt"
            {{dDragAndDropTarget
              accepts="row"
              canDrop=blowUp
              onDrop=recordDrop
            }}
          >tgt</div>
        </template>
      );

      try {
        const dataTransfer = new DataTransfer();
        await startDrag("#src", { dataTransfer });
        await dragOver("#tgt", { dataTransfer });

        assert
          .dom("#tgt")
          .doesNotHaveClass(
            /^--drag-/,
            "a gate that threw has decided nothing, so the target does not light"
          );

        await dragEvent("#tgt", "drop", { dataTransfer, ...centerOf("#tgt") });
        await dragEvent("#src", "dragend", {
          dataTransfer,
          ...centerOf("#src"),
        });

        assert.deepEqual(drops, [], "and the drop is refused");
        assert.true(
          reported.length >= 1,
          `each throw is raised for the test (${reported.length} seen)`
        );
        assert.strictEqual(
          new Set(notices).size,
          1,
          "and every report goes through the drag-and-drop notice"
        );
        assert.strictEqual(
          notices[0],
          "broken_drag_and_drop_alert",
          "under its own message key"
        );
      } finally {
        document.removeEventListener("discourse-error", collect);
      }
    });

    test("a throwing canDrag refuses to start the drag", async function (assert) {
      const reported = [];
      setupOnerror((error) => reported.push(error));

      const drops = [];
      const recordDrop = () => drops.push("drop");

      await render(
        <template>
          <div
            id="src"
            {{dDragAndDropSource type="row" canDrag=blowUp}}
          >src</div>
          <div
            id="tgt"
            {{dDragAndDropTarget accepts="row" onDrop=recordDrop}}
          >tgt</div>
        </template>
      );

      await simulateDrag("#src", "#tgt", {
        dataTransfer: new DataTransfer(),
      });

      assert.deepEqual(drops, [], "no drag starts, so nothing is dropped");
      assert
        .dom("#src")
        .doesNotHaveClass(
          "--dragging",
          "and the source is never marked as dragging"
        );
      assert.true(
        reported.length >= 1,
        `and the throwing gate was raised (${reported.length} seen)`
      );
    });

    test("a throwing getData is reported and the drag record carries no data", async function (assert) {
      const reported = [];
      setupOnerror((error) => reported.push(error));

      const targets = [];
      const recordDrop = ({ location }) =>
        targets.push(location.current.dropTargets[0].data);

      await render(
        <template>
          <div
            id="src"
            {{dDragAndDropSource type="row" onDrop=recordDrop}}
          >src</div>
          <div
            id="tgt"
            {{dDragAndDropTarget accepts="row" getData=blowUp}}
          >tgt</div>
        </template>
      );

      await simulateDrag("#src", "#tgt", { dataTransfer: new DataTransfer() });

      assert.deepEqual(
        targets,
        [{}],
        "the drop lands with an empty record in place of what the consumer failed to attach"
      );
      assert.true(
        reported.length >= 1,
        `and the throwing getData was raised (${reported.length} seen)`
      );
    });

    test("a throwing getIsSticky is reported and treated as not sticky", async function (assert) {
      const reported = [];
      setupOnerror((error) => reported.push(error));

      const events = [];
      const onEnter = () => events.push("enter");
      const onLeave = () => events.push("leave");

      await render(
        <template>
          <div id="src" {{dDragAndDropSource type="row"}}>src</div>
          <div
            id="tgt"
            {{dDragAndDropTarget
              accepts="row"
              position="before"
              getIsSticky=blowUp
              onDragEnter=onEnter
              onDragLeave=onLeave
            }}
          >tgt</div>
          <div id="away" style="height: 50px">away</div>
        </template>
      );

      const dataTransfer = new DataTransfer();
      await startDrag("#src", { dataTransfer });
      await dragOver("#tgt", { dataTransfer });
      await dragOver("#away", { dataTransfer });
      await dragEvent("#src", "dragend", { dataTransfer, ...centerOf("#src") });

      assert.deepEqual(
        events,
        ["enter", "leave"],
        "a gate that threw decided nothing, so the target lets go when the pointer leaves"
      );
      assert.true(
        reported.length >= 1,
        `and the throwing stickiness gate was raised (${reported.length} seen)`
      );
    });

    test("a throwing preview cleanup is reported and leaves no preview container behind", async function (assert) {
      const reported = [];
      setupOnerror((error) => reported.push(error));

      const notices = [];
      const collect = (event) => notices.push(event.detail.messageKey);
      document.addEventListener("discourse-error", collect);

      const drops = [];
      const recordDrop = () => drops.push("drop");
      const renderPreview = ({ container }) => {
        container.dataset.previewMarker = "";
        container.textContent = "preview";
        return blowUp;
      };

      try {
        await render(
          <template>
            <div
              id="src"
              {{dDragAndDropSource type="row" dragPreview=renderPreview}}
            >src</div>
            <div
              id="tgt"
              {{dDragAndDropTarget accepts="row" onDrop=recordDrop}}
            >tgt</div>
          </template>
        );

        await simulateDrag("#src", "#tgt", {
          dataTransfer: new DataTransfer(),
        });

        assert.deepEqual(drops, ["drop"], "the drop still lands");
        assert.deepEqual(
          notices,
          ["broken_drag_and_drop_alert"],
          "the throwing cleanup is reported once, as a consumer error"
        );
        assert
          .dom("[data-preview-marker]", document.body)
          .doesNotExist("and the offscreen preview container is still removed");
      } finally {
        document.removeEventListener("discourse-error", collect);
      }
    });

    test("a throwing preview renderer is reported and the drag still starts", async function (assert) {
      const reported = [];
      setupOnerror((error) => reported.push(error));

      const drops = [];
      const recordDrop = () => drops.push("drop");

      await render(
        <template>
          <div
            id="src"
            {{dDragAndDropSource type="row" dragPreview=blowUp}}
          >src</div>
          <div
            id="tgt"
            {{dDragAndDropTarget accepts="row" onDrop=recordDrop}}
          >tgt</div>
        </template>
      );

      await simulateDrag("#src", "#tgt", { dataTransfer: new DataTransfer() });

      assert.deepEqual(
        drops,
        ["drop"],
        "the drag runs to a drop without a preview"
      );
      assert.true(
        reported.length >= 1,
        `and the throwing renderer was raised (${reported.length} seen)`
      );
    });

    test("a throwing source onDragStart is reported and the drag still runs to its drop", async function (assert) {
      const reported = [];
      setupOnerror((error) => reported.push(error));

      const drops = [];
      const recordDrop = () => drops.push("drop");

      await render(
        <template>
          <div
            id="src"
            {{dDragAndDropSource type="row" onDragStart=blowUp}}
          >src</div>
          <div
            id="tgt"
            {{dDragAndDropTarget accepts="row" onDrop=recordDrop}}
          >tgt</div>
        </template>
      );

      await simulateDrag("#src", "#tgt", { dataTransfer: new DataTransfer() });

      assert.deepEqual(drops, ["drop"], "the target still receives the drop");
      assert
        .dom("#src")
        .doesNotHaveClass(
          "--dragging",
          "and the source is cleaned up after it"
        );
      assert.true(reported.length >= 1, "the throwing callback was raised");
    });

    test("a throwing source onDrop still runs the teardown that was waiting on the drag", async function (assert) {
      const reported = [];
      setupOnerror((error) => reported.push(error));
      const state = new (class {
        @tracked disabled = false;
      })();

      await render(
        <template>
          <div
            id="src"
            {{dDragAndDropSource
              type="row"
              onDrop=blowUp
              disabled=state.disabled
            }}
          >src</div>
          <div id="tgt" {{dDragAndDropTarget accepts="row"}}>tgt</div>
        </template>
      );

      const dataTransfer = new DataTransfer();
      await startDrag("#src", { dataTransfer });
      await dragOver("#tgt", { dataTransfer });

      // Disabled mid-drag: the registration waits for the drag to end.
      state.disabled = true;
      await settled();
      assert.dom("#src").hasAttribute("data-drag-source", "", "waiting");

      await dragEvent("#tgt", "drop", { dataTransfer, ...centerOf("#tgt") });
      await dragEvent("#src", "dragend", { dataTransfer, ...centerOf("#src") });
      await settled();

      assert
        .dom("#src")
        .doesNotHaveAttribute(
          "data-drag-source",
          "the consumer's throw does not leave the element registered"
        );
      assert.true(reported.length >= 1, "and the throw was raised");
    });
  });

  module("arg changes reach a drag already in flight", function () {
    test("disabling a source mid-drag still reports to its current callbacks", async function (assert) {
      const calls = [];
      const state = new (class {
        @tracked disabled = false;
        @tracked onDragEnd = () => calls.push("before");
      })();

      await render(
        <template>
          <div
            id="src"
            {{dDragAndDropSource
              type="row"
              disabled=state.disabled
              onDragEnd=state.onDragEnd
            }}
          >src</div>
          <div id="tgt" {{dDragAndDropTarget accepts="row"}}>tgt</div>
        </template>
      );

      const dataTransfer = new DataTransfer();
      await dragEvent("#src", "dragstart", {
        dataTransfer,
        ...centerOf("#src"),
      });
      await dragEvent("#tgt", "dragenter", {
        dataTransfer,
        ...centerOf("#tgt"),
      });

      // Both in one flush. The disable detaches the registration while the drag
      // it is waiting on is still running, and the callback has been replaced.
      state.disabled = true;
      state.onDragEnd = () => calls.push("after");
      await settled();

      await dragEvent("#tgt", "dragover", {
        dataTransfer,
        ...centerOf("#tgt"),
      });
      await dragEvent("#tgt", "drop", { dataTransfer, ...centerOf("#tgt") });

      assert.deepEqual(
        calls,
        ["after"],
        "the drag reports to the callback the consumer has now, not the one it had at press"
      );
    });
  });

  /**
   * The line needs a containing block, but a target that positions itself already
   * has one. Declared at zero specificity so the consumer's own rule wins.
   */
  module(
    "the indicator leaves a consumer's positioning alone",
    function (indicatorHooks) {
      let consumerSheet;

      indicatorHooks.afterEach(function () {
        consumerSheet?.remove();
        consumerSheet = null;
      });

      test("a positioned drop target keeps its own positioning while showing an indicator", async function (assert) {
        // At the top of the head, so it loses on source order and can only take
        // effect by outranking the primitive's default.
        consumerSheet = document.createElement("style");
        consumerSheet.textContent = ".positioned { position: absolute; }";
        document.head.insertBefore(consumerSheet, document.head.firstChild);

        // The stylesheet is the subject, so the mark and the class a lit target
        // carries are written out rather than reached through a drag.
        await render(
          <template>
            <div
              id="tgt"
              class="positioned --drag-above"
              data-drop-target
            >tgt</div>
          </template>
        );

        assert.strictEqual(
          getComputedStyle(find("#tgt")).position,
          "absolute",
          "the target is still positioned the way its consumer asked"
        );
      });

      test("a drop target that positions nothing still gets the containing block the line needs", async function (assert) {
        await render(
          <template>
            <div id="tgt" class="--drag-above" data-drop-target>tgt</div>
          </template>
        );

        assert.strictEqual(
          getComputedStyle(find("#tgt")).position,
          "relative",
          "so the line has something to resolve against"
        );
      });
    }
  );

  module("gates and feedback the consumer supplies", function () {
    test("canDrag returning false stops the drag before it starts", async function (assert) {
      const drops = [];
      const recordDrop = () => drops.push("drop");
      const refuse = () => false;

      await render(
        <template>
          <div
            id="src"
            {{dDragAndDropSource type="row" canDrag=refuse}}
          >src</div>
          <div
            id="tgt"
            {{dDragAndDropTarget accepts="row" onDrop=recordDrop}}
          >tgt</div>
        </template>
      );

      await simulateDrag("#src", "#tgt", { dataTransfer: new DataTransfer() });

      assert.deepEqual(drops, [], "nothing is dropped");
      assert
        .dom("#src")
        .doesNotHaveClass(
          "--dragging",
          "and the source never enters the drag state"
        );
    });

    test("canDrop returning false refuses a drag the type filter would have taken", async function (assert) {
      const drops = [];
      const recordDrop = () => drops.push("drop");
      const refuse = () => false;

      await render(
        <template>
          <div id="src" {{dDragAndDropSource type="row"}}>src</div>
          <div
            id="tgt"
            {{dDragAndDropTarget
              accepts="row"
              canDrop=refuse
              onDrop=recordDrop
            }}
          >tgt</div>
        </template>
      );

      await simulateDrag("#src", "#tgt", { dataTransfer: new DataTransfer() });

      assert.deepEqual(
        drops,
        [],
        "the identity gate refuses what the type gate allowed"
      );
      assert
        .dom("#tgt")
        .doesNotHaveClass(
          "--drag-above",
          "and no indicator is drawn for a drop that cannot land"
        );
    });

    test("getDropEffect decides the effect recorded against this target", async function (assert) {
      const effects = [];
      const copyEffect = () => "copy";
      const recordDrop = ({ location }) =>
        effects.push(location.current.dropTargets[0].dropEffect);

      await render(
        <template>
          <div
            id="src"
            {{dDragAndDropSource
              type="row"
              effectAllowed="copyMove"
              onDrop=recordDrop
            }}
          >src</div>
          <div
            id="tgt"
            {{dDragAndDropTarget accepts="row" getDropEffect=copyEffect}}
          >tgt</div>
        </template>
      );

      await simulateDrag("#src", "#tgt", { dataTransfer: new DataTransfer() });

      // Read from the drag's own record rather than the `dataTransfer`, whose
      // `dropEffect` a synthetic drag reports as `none` however it was set up.
      assert.deepEqual(
        effects,
        ["copy"],
        "the effect the target asked for is the one the drag carries for it"
      );
    });

    test("getData attaches target metadata the drag carries to the source", async function (assert) {
      const targets = [];
      const describeTarget = () => ({ slot: "inbox" });
      const recordDrop = ({ location }) =>
        targets.push(location.current.dropTargets[0].data);

      await render(
        <template>
          <div
            id="src"
            {{dDragAndDropSource type="row" onDrop=recordDrop}}
          >src</div>
          <div
            id="tgt"
            {{dDragAndDropTarget accepts="row" getData=describeTarget}}
          >tgt</div>
        </template>
      );

      await simulateDrag("#src", "#tgt", { dataTransfer: new DataTransfer() });

      assert.deepEqual(
        targets,
        [{ slot: "inbox" }],
        "the source reads what the target attached to its own record of the drag"
      );
    });

    test("a sticky target keeps its enter while the pointer is outside it and is left when stickiness ends", async function (assert) {
      const state = new (class {
        @tracked sticky = true;
      })();
      const isSticky = () => state.sticky;
      const events = [];
      const onEnter = () => events.push("enter");
      const onLeave = () => events.push("leave");

      await render(
        <template>
          <div id="src" {{dDragAndDropSource type="row"}}>src</div>
          <div
            id="tgt"
            {{dDragAndDropTarget
              accepts="row"
              position="before"
              getIsSticky=isSticky
              onDragEnter=onEnter
              onDragLeave=onLeave
            }}
          >tgt</div>
          <div id="away" style="height: 50px">away</div>
        </template>
      );

      const dataTransfer = new DataTransfer();
      await startDrag("#src", { dataTransfer });
      await dragOver("#tgt", { dataTransfer });
      await dragOver("#away", { dataTransfer });

      assert.deepEqual(
        events,
        ["enter"],
        "stickiness keeps the role while the pointer is outside"
      );
      assert
        .dom("#tgt")
        .hasClass("--drag-above", "and the indicator stays with the role");

      state.sticky = false;
      await settled();
      await dragEvent("#away", "dragover", {
        dataTransfer,
        ...centerOf("#away"),
      });

      assert.deepEqual(
        events,
        ["enter", "leave"],
        "once stickiness ends the target is left exactly once"
      );
      assert.dom("#tgt").doesNotHaveClass("--drag-above");

      await dragEvent("#src", "dragend", { dataTransfer, ...centerOf("#src") });
    });

    test("indicator=false drops the marker without dropping the callbacks", async function (assert) {
      const entered = [];
      const recordEnter = () => entered.push("enter");

      await render(
        <template>
          <div id="src" {{dDragAndDropSource type="row"}}>src</div>
          <div
            id="tgt"
            {{dDragAndDropTarget
              accepts="row"
              position="before"
              indicator=false
              onDragEnter=recordEnter
            }}
          >tgt</div>
        </template>
      );

      const dataTransfer = new DataTransfer();
      await startDrag("#src", { dataTransfer });
      await dragOver("#tgt", { dataTransfer });

      assert
        .dom("#tgt")
        .doesNotHaveClass(
          "--drag-above",
          "the consumer draws its own feedback"
        );
      assert.deepEqual(
        entered,
        ["enter"],
        "and is still told the drag arrived, so it can draw it"
      );
    });
  });
});
