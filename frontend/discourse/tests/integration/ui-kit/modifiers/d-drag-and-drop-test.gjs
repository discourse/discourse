import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { find, render, settled, setupOnerror } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  centerOf,
  dragEvent,
  simulateDrag,
} from "discourse/tests/helpers/ui-kit/drag-and-drop-helper";
import { registerDragAndDropMonitor } from "discourse/ui-kit/modifiers/d-drag-and-drop-monitor";
import dDragAndDropSource, {
  registerDragAndDropSource,
} from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";

module("Integration | ui-kit | Modifier | dragAndDrop", function (hooks) {
  setupRenderingTest(hooks);

  module("marker attribute lifecycle", function () {
    test("marks every registered element after render", async function (assert) {
      await render(
        <template>
          <div id="source" {{dDragAndDropSource type="row"}}>source</div>
          <div id="target" {{dDragAndDropTarget accepts="row"}}>target</div>
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

  test("simulateDrag merges independent partial coordinate overrides", async function (assert) {
    const events = {};

    // A registered pair rather than bare elements, because that is what every
    // caller passes and what the helper now refuses to run without.
    await render(
      <template>
        <div id="src" {{dDragAndDropSource type="row"}}>source</div>
        <div id="tgt" {{dDragAndDropTarget accepts="row"}}>target</div>
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

    // The registration moves with the handle, so the superseded one stops being
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

  test("acceptsSelf checks the raw source element without target fallback", async function (assert) {
    let drops = 0;
    let rawElement = "monitor never ran";
    let normalisedElement = "canDrop never ran";
    const onDrop = () => drops++;
    const canDrop = ({ source }) => {
      normalisedElement = source.element;
      return true;
    };
    const cleanupMonitor = registerDragAndDropMonitor(() => ({
      onDragStart: ({ source }) => {
        delete source.element;
        rawElement = source.element;
      },
    }));

    await render(
      <template>
        <div id="src" {{dDragAndDropSource type="row"}}>source</div>
        <div
          id="tgt"
          {{dDragAndDropTarget
            accepts="row"
            acceptsSelf=false
            canDrop=canDrop
            onDrop=onDrop
          }}
        >target</div>
      </template>
    );

    await simulateDrag("#src", "#tgt", {
      dataTransfer: new DataTransfer(),
    });
    cleanupMonitor();

    // Read back, because the whole fixture rests on this mutation landing: if the
    // delete silently did nothing, the drop below would succeed for the ordinary
    // reason and prove nothing about the fallback.
    assert.strictEqual(
      rawElement,
      undefined,
      "the raw source element really was removed"
    );
    // The source publishes the element it stands for in the payload, so the
    // normalisation has something to name even once the raw one is gone and
    // never reaches the fallback that would read as self. That is what makes a
    // deleted raw element harmless rather than a refused drop.
    assert.strictEqual(
      normalisedElement,
      find("#src"),
      "the normalised payload still names the source, not the target it fell through to"
    );
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

    assert
      .dom("#outer")
      .doesNotHaveClass(
        "--drag-inside",
        "dropping on the child clears the parent indicator"
      );
  });

  test("a drop clears an ancestor indicator that never saw another drag event", async function (assert) {
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
      .hasClass("--drag-inside", "the ancestor is showing an indicator");

    // Straight from the ancestor to a drop on the child, with no drag event in
    // between: the ancestor's own enter/drag clears never run again, so the
    // unconditional clear in `onDrop` is the only thing left to drop it.
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
        "a drop clears the ancestor even though it is no longer the deepest target"
      );
  });

  test("target modifier picks up arg changes without re-registering", async function (assert) {
    // The modifier runs `modify()` only once (its body reads no tracked
    // arg properties), so the underlying target is registered just once. The closure
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
      await dragEvent("#src", "dragstart", {
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

      // The source defers its consumer callbacks to the next task, so tearing
      // it down in between is what a route transition or a re-render dropping
      // the row does.
      find("#tgt").dispatchEvent(
        new DragEvent("drop", { bubbles: true, dataTransfer })
      );
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
      await dragEvent("#src", "dragstart", {
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

      find("#tgt").dispatchEvent(
        new DragEvent("drop", { bubbles: true, dataTransfer })
      );
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
      // being kept has to be let go of before a replacement is made.
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

    test("superseding a detached source keeps the callbacks it still owes", async function (assert) {
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
      await dragEvent("#src", "dragstart", {
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

      find("#tgt").dispatchEvent(
        new DragEvent("drop", { bubbles: true, dataTransfer })
      );

      const work = release({ cancelPending: false });

      // Something has taken this registration's place, which says nothing about
      // the drag that already finished. The consumer is still there and is still
      // owed the end of it.
      work.supersede();
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

    test("detached work reports itself outstanding until its dispatch fires", async function (assert) {
      const args = { type: "row", onDragEnd: () => {}, onDrop: () => {} };

      await render(
        <template>
          <div id="src">src</div>
          <div id="tgt" {{dDragAndDropTarget accepts="row"}}>tgt</div>
        </template>
      );

      const release = registerDragAndDropSource(find("#src"), () => args);

      const dataTransfer = new DataTransfer();
      await dragEvent("#src", "dragstart", {
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

      find("#tgt").dispatchEvent(
        new DragEvent("drop", { bubbles: true, dataTransfer })
      );

      const work = release({ cancelPending: false });

      assert.true(
        work.outstanding(),
        "a dispatch is still scheduled, so a holder has to keep it"
      );

      await settled();

      assert.false(
        work.outstanding(),
        "and stops being owed once that dispatch has run"
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
      await dragEvent("#src", "dragstart", {
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

      find("#tgt").dispatchEvent(
        new DragEvent("drop", { bubbles: true, dataTransfer })
      );

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
      await dragEvent("#src", "dragstart", {
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

      // Detached, but kept alive to report the drag it is in the middle of.
      state.disabled = true;
      await settled();

      // The drop schedules the consumer callbacks, and the row goes away before
      // the runloop flushes them. Whatever is still holding that dispatch has to
      // be reachable from here, or nothing can call it off.
      find("#tgt").dispatchEvent(
        new DragEvent("drop", { bubbles: true, dataTransfer })
      );
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
      await dragEvent("#src", "dragstart", {
        dataTransfer,
        ...centerOf("#src"),
      });
      // Straight onto the child, so the ancestor is in the stack but never the
      // deepest and so never forwards an enter.
      await dragEvent("#inner", "dragenter", {
        dataTransfer,
        ...centerOf("#inner"),
      });
      await dragEvent("#inner", "dragover", {
        dataTransfer,
        ...centerOf("#inner"),
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
      await dragEvent("#src", "dragstart", {
        dataTransfer: firstTransfer,
        ...centerOf("#src"),
      });
      await dragEvent("#target", "dragenter", {
        dataTransfer: firstTransfer,
        ...centerOf("#target"),
      });
      await dragEvent("#target", "dragover", {
        dataTransfer: firstTransfer,
        ...centerOf("#target"),
      });
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
      await dragEvent("#src", "dragstart", {
        dataTransfer: secondTransfer,
        ...centerOf("#src"),
      });
      await dragEvent("#target", "dragenter", {
        dataTransfer: secondTransfer,
        ...centerOf("#target"),
      });
      await dragEvent("#target", "dragover", {
        dataTransfer: secondTransfer,
        ...centerOf("#target"),
      });
      await dragEvent("#away", "dragenter", {
        dataTransfer: secondTransfer,
        ...centerOf("#away"),
      });
      await dragEvent("#away", "dragover", {
        dataTransfer: secondTransfer,
        ...centerOf("#away"),
      });
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

      document.removeEventListener("discourse-error", collect);
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
      setupOnerror(() => {});

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

      await simulateDrag("#src", "#tgt", {
        dataTransfer: new DataTransfer(),
      });

      assert.deepEqual(
        drops,
        [],
        "a gate that threw decided nothing, so the drop is refused"
      );
    });

    test("a throwing canDrag refuses to start the drag", async function (assert) {
      setupOnerror(() => {});

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

        await render(
          <template>
            <div id="src" {{dDragAndDropSource type="row"}}>src</div>
            <div
              id="tgt"
              class="positioned"
              {{dDragAndDropTarget accepts="row" position="before"}}
            >tgt</div>
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
        await dragEvent("#tgt", "dragover", {
          dataTransfer,
          ...centerOf("#tgt"),
        });

        assert.dom("#tgt").hasClass("--drag-above", "the indicator is showing");
        assert.strictEqual(
          getComputedStyle(find("#tgt")).position,
          "absolute",
          "and the target is still positioned the way its consumer asked"
        );
      });

      test("a drop target that positions nothing still gets the containing block the line needs", async function (assert) {
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
        await dragEvent("#src", "dragstart", {
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

        assert.dom("#tgt").hasClass("--drag-above", "the indicator is showing");
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
      await dragEvent("#src", "dragstart", {
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
