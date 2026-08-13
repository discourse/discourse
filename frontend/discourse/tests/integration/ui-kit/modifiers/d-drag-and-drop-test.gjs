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
  externalDragOver,
  simulateDrag,
  simulateExternalDrag,
  simulateUnsourcedDrag,
} from "discourse/tests/helpers/ui-kit/drag-and-drop-helper";
import dDragAndDropAutoScroll from "discourse/ui-kit/modifiers/d-drag-and-drop-auto-scroll";
import dDragAndDropExternalTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-external-target";
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

  module("external target behaviour", function () {
    function fileTransfer() {
      const dataTransfer = new DataTransfer();
      dataTransfer.items.add(
        new File(["payload"], "a.txt", { type: "text/plain" })
      );
      return dataTransfer;
    }

    function textTransfer() {
      const dataTransfer = new DataTransfer();
      dataTransfer.setData("text/plain", "dropped text");
      return dataTransfer;
    }

    test("hands the consumer a payload it can read without importing the library", async function (assert) {
      let seen = null;
      const onDrop = ({ source }) => {
        seen = {
          containsFiles: source.containsFiles(),
          names: source.getFiles().map((file) => file.name),
        };
      };

      await render(
        <template>
          <div
            id="ext"
            {{dDragAndDropExternalTarget accepts="files" onDrop=onDrop}}
          >ext</div>
        </template>
      );

      await simulateExternalDrag("#ext", { dataTransfer: fileTransfer() });

      assert.deepEqual(
        seen,
        { containsFiles: true, names: ["a.txt"] },
        "the decorated source answers about its own payload and returns the files"
      );
    });

    test("accepts filters which external kinds engage the target", async function (assert) {
      const drops = [];
      const onFilesDrop = () => drops.push("files");
      const onTextDrop = () => drops.push("text");

      await render(
        <template>
          <div
            id="files-only"
            {{dDragAndDropExternalTarget accepts="files" onDrop=onFilesDrop}}
          >files</div>
          <div
            id="text-only"
            {{dDragAndDropExternalTarget accepts="text" onDrop=onTextDrop}}
          >text</div>
        </template>
      );

      await simulateExternalDrag("#files-only", {
        dataTransfer: textTransfer(),
      });

      assert.deepEqual(
        drops,
        [],
        "a text drag does not reach a target that only accepts files"
      );
      assert
        .dom("#files-only")
        .doesNotHaveClass(
          "--drag-over-external",
          "and it lights no indicator on the way past"
        );

      await simulateExternalDrag("#text-only", {
        dataTransfer: textTransfer(),
      });

      assert.deepEqual(
        drops,
        ["text"],
        "the same drag reaches the target whose kind it matches"
      );
    });

    test("canDrop refuses a drop the accepts filter would have allowed", async function (assert) {
      let drops = 0;
      const onDrop = () => drops++;
      const canDrop = () => false;

      await render(
        <template>
          <div
            id="ext"
            {{dDragAndDropExternalTarget
              accepts="files"
              canDrop=canDrop
              onDrop=onDrop
            }}
          >ext</div>
        </template>
      );

      await simulateExternalDrag("#ext", { dataTransfer: fileTransfer() });

      assert.strictEqual(drops, 0, "the synchronous gate refuses the drop");
    });

    test("a gate that turns false after the last dragover refuses the drop", async function (assert) {
      let allowed = true;
      let drops = 0;
      const canDrop = () => allowed;
      const onDrop = () => drops++;

      await render(
        <template>
          <div
            id="ext"
            {{dDragAndDropExternalTarget
              accepts="files"
              canDrop=canDrop
              onDrop=onDrop
            }}
          >ext</div>
        </template>
      );

      const dataTransfer = fileTransfer();
      await externalDragOver("#ext", { dataTransfer });

      // The library settles its target stack at the last dragover and does not
      // re-ask the gate at drop, so refusing here is this modifier's own doing.
      allowed = false;
      await dragEvent("#ext", "drop", {
        dataTransfer,
        ...centerOf("#ext"),
      });

      assert.strictEqual(
        drops,
        0,
        "a permission withdrawn before release does not act"
      );
    });

    test("indicator=false suppresses the hover class without refusing the drop", async function (assert) {
      let drops = 0;
      const onDrop = () => drops++;

      await render(
        <template>
          <div
            id="ext"
            {{dDragAndDropExternalTarget
              accepts="files"
              indicator=false
              onDrop=onDrop
            }}
          >ext</div>
        </template>
      );

      const dataTransfer = fileTransfer();
      await externalDragOver("#ext", { dataTransfer });

      assert
        .dom("#ext")
        .doesNotHaveClass(
          "--drag-over-external",
          "the hover class is suppressed"
        );

      await dragEvent("#ext", "drop", { dataTransfer, ...centerOf("#ext") });

      assert.strictEqual(
        drops,
        1,
        "suppressing the indicator does not suppress the drop"
      );
    });

    test("external drop position resolves either side of the cursor midpoint", async function (assert) {
      const drops = [];
      const onDrop = (payload) => drops.push(payload.position);

      await render(
        <template>
          <div
            id="ext"
            style="height: 100px"
            {{dDragAndDropExternalTarget accepts="text" axis="y" onDrop=onDrop}}
          >ext</div>
        </template>
      );

      const rect = find("#ext").getBoundingClientRect();

      await simulateExternalDrag("#ext", {
        dataTransfer: textTransfer(),
        coordinates: { clientY: rect.top + 5 },
      });
      await simulateExternalDrag("#ext", {
        dataTransfer: textTransfer(),
        coordinates: { clientY: rect.top + rect.height - 5 },
      });

      assert.deepEqual(
        drops,
        ["before", "after"],
        "an external drop lands before or after the target depending on which side of its midpoint the cursor is"
      );
    });

    test("external drop position drives the same indicator classes the element target uses", async function (assert) {
      await render(
        <template>
          <div
            id="ext"
            style="height: 100px"
            {{dDragAndDropExternalTarget accepts="text" axis="y"}}
          >ext</div>
        </template>
      );

      const rect = find("#ext").getBoundingClientRect();
      const dataTransfer = textTransfer();

      await externalDragOver("#ext", {
        dataTransfer,
        coordinates: { clientY: rect.top + 5 },
      });

      assert
        .dom("#ext")
        .hasClass("--drag-above", "the indicator marks the upper half")
        .doesNotHaveClass(
          "--drag-over-external",
          "and the positionless hover class is not also applied"
        );

      await externalDragOver("#ext", {
        dataTransfer,
        coordinates: { clientY: rect.top + rect.height - 5 },
      });

      assert
        .dom("#ext")
        .hasClass("--drag-below", "crossing the midpoint swaps the indicator")
        .doesNotHaveClass(
          "--drag-above",
          "rather than accumulating both positions"
        );
    });

    test("external drop position honours the x axis", async function (assert) {
      const drops = [];
      const onDrop = (payload) => drops.push(payload.position);

      await render(
        <template>
          <div
            id="ext"
            style="width: 200px"
            {{dDragAndDropExternalTarget accepts="text" axis="x" onDrop=onDrop}}
          >ext</div>
        </template>
      );

      const rect = find("#ext").getBoundingClientRect();

      await simulateExternalDrag("#ext", {
        dataTransfer: textTransfer(),
        coordinates: { clientX: rect.left + 5 },
      });

      assert.deepEqual(
        drops,
        ["before"],
        "the midpoint is measured along the named axis"
      );
      assert
        .dom("#ext")
        .doesNotHaveClass(
          "--drag-above",
          "and the class comes from the x vocabulary, not the y one"
        );
    });

    test("external drop position takes a fixed position over the midpoint", async function (assert) {
      const drops = [];
      const onDrop = (payload) => drops.push(payload.position);

      await render(
        <template>
          <div
            id="ext"
            style="height: 100px"
            {{dDragAndDropExternalTarget
              accepts="text"
              position="inside"
              onDrop=onDrop
            }}
          >ext</div>
        </template>
      );

      const rect = find("#ext").getBoundingClientRect();
      const dataTransfer = textTransfer();

      await externalDragOver("#ext", {
        dataTransfer,
        coordinates: { clientY: rect.top + 5 },
      });

      assert
        .dom("#ext")
        .hasClass(
          "--drag-inside",
          "a fixed position ignores which half the cursor is in"
        );

      await dragEvent("#ext", "drop", {
        dataTransfer,
        clientY: rect.top + 5,
        clientX: rect.left + 5,
      });

      assert.deepEqual(drops, ["inside"], "and reports itself on the drop");
    });

    test("external drop position is null once the drag leaves", async function (assert) {
      const seen = [];
      const onDragEnter = (payload) => seen.push(["enter", payload.position]);
      const onDragLeave = (payload) => seen.push(["leave", payload.position]);

      await render(
        <template>
          <div
            id="ext"
            style="height: 100px"
            {{dDragAndDropExternalTarget
              accepts="text"
              axis="y"
              onDragEnter=onDragEnter
              onDragLeave=onDragLeave
            }}
          >ext</div>
        </template>
      );

      const rect = find("#ext").getBoundingClientRect();
      const dataTransfer = textTransfer();

      await externalDragOver("#ext", {
        dataTransfer,
        coordinates: { clientY: rect.top + 5 },
      });
      await dragEvent("#ext", "dragleave", {
        dataTransfer,
        ...centerOf("#ext"),
      });

      assert.deepEqual(
        seen,
        [
          ["enter", "before"],
          ["leave", null],
        ],
        "the position is where a drop would have landed while hovering, and nothing once there is nowhere to land"
      );
      assert
        .dom("#ext")
        .doesNotHaveClass("--drag-above", "and the indicator is dropped");
    });

    test("external drop position stays out of the way when neither arg is given", async function (assert) {
      const drops = [];
      const onDrop = (payload) => drops.push(payload.position);

      await render(
        <template>
          <div
            id="ext"
            style="height: 100px"
            {{dDragAndDropExternalTarget accepts="text" onDrop=onDrop}}
          >ext</div>
        </template>
      );

      const rect = find("#ext").getBoundingClientRect();
      const dataTransfer = textTransfer();

      await externalDragOver("#ext", {
        dataTransfer,
        coordinates: { clientY: rect.top + 5 },
      });

      assert
        .dom("#ext")
        .hasClass(
          "--drag-over-external",
          "a target that asked for no position keeps the single hover class"
        )
        .doesNotHaveClass(
          "--drag-above",
          "rather than being opted into the positional vocabulary"
        );

      await dragEvent("#ext", "drop", {
        dataTransfer,
        clientY: rect.top + 5,
        clientX: rect.left + 5,
      });

      assert.deepEqual(
        drops,
        [null],
        "and reports no position, because it was never asked to resolve one"
      );
    });
  });

  module("adopting an unsourced drag", function () {
    function linkTransfer() {
      const dataTransfer = new DataTransfer();
      dataTransfer.setData("text/uri-list", "https://example.com/adopted");
      dataTransfer.setData("text/plain", "https://example.com/adopted");
      return dataTransfer;
    }

    const WEB_LINK = {
      type: "web-link",
      match: ({ element }) => Boolean(element.closest("a[href]")),
    };

    test("adopting an unsourced drag delivers a link the browser dragged from the page", async function (assert) {
      let seen = null;
      const onDrop = ({ source }) => {
        seen = { type: source.type, urls: source.native.getURLs() };
      };

      await render(
        <template>
          <a id="anchor" href="https://example.com/adopted">a link</a>
          <div
            id="zone"
            {{dDragAndDropTarget adopts=WEB_LINK onDrop=onDrop}}
          >zone</div>
        </template>
      );

      await simulateUnsourcedDrag("#anchor", "#zone", {
        dataTransfer: linkTransfer(),
      });

      assert.deepEqual(
        seen,
        { type: "web-link", urls: ["https://example.com/adopted"] },
        "a drag nothing registered reaches the target as an ordinary drop, named by the adoption and carrying the payload the browser supplied"
      );
    });

    test("the service reports an adopted drag by its adoption, not its routing", async function (assert) {
      // The target strips the adoption's routing keys before a consumer sees
      // them; a reader of the service must meet the same shape.
      const dnd = this.owner.lookup("service:drag-and-drop");

      await render(
        <template>
          <a id="anchor" href="https://example.com/adopted">a link</a>
          <div id="zone" {{dDragAndDropTarget adopts=WEB_LINK}}>zone</div>
        </template>
      );

      const dataTransfer = linkTransfer();
      await dragEvent("#anchor", "dragstart", {
        dataTransfer,
        ...centerOf("#anchor"),
      });

      assert.strictEqual(
        dnd.currentDrag.type,
        "web-link",
        "currentDrag.type is the adoption's own type"
      );
      assert.deepEqual(
        dnd.currentDrag.data,
        {},
        "the routing keys never reach a reader of currentDrag.data"
      );
      assert.deepEqual(
        dnd.currentDrag.native.getURLs(),
        ["https://example.com/adopted"],
        "the native payload sits beside data, as a target reports it"
      );

      await dragEvent("#anchor", "dragend", {
        dataTransfer,
        ...centerOf("#anchor"),
      });

      assert.strictEqual(dnd.currentDrag, null, "cleared once the drag ends");
    });

    test("adopting an unsourced drag is refused by a target that did not ask", async function (assert) {
      const drops = [];
      const onDrop = () => drops.push("dropped");

      await render(
        <template>
          <a id="anchor" href="https://example.com/adopted">a link</a>
          <div id="zone" {{dDragAndDropTarget onDrop=onDrop}}>zone</div>
        </template>
      );

      await simulateUnsourcedDrag("#anchor", "#zone", {
        dataTransfer: linkTransfer(),
      });

      assert.deepEqual(
        drops,
        [],
        "an omitted accepts filter does not quietly admit a drag no source registered"
      );
    });

    test("adopting an unsourced drag leaves a registered source alone", async function (assert) {
      const drops = [];
      const onDrop = ({ source }) => drops.push(source.type);

      await render(
        <template>
          <div id="row" {{dDragAndDropSource type="row" data=(hash id=1)}}>
            <a id="inner" href="https://example.com/adopted">a link</a>
          </div>
          <div
            id="zone"
            {{dDragAndDropTarget accepts="row" adopts=WEB_LINK onDrop=onDrop}}
          >zone</div>
        </template>
      );

      await simulateDrag("#row", "#zone", { dataTransfer: linkTransfer() });

      assert.deepEqual(
        drops,
        ["row"],
        "a drag starting inside a registered source stays that source's drag rather than being adopted out from under it"
      );
    });

    test("adopting an unsourced drag refuses a dragged text selection", async function (assert) {
      const drops = [];
      const onDrop = () => drops.push("dropped");

      await render(
        <template>
          {{! Dragging a selected URL out of an editable region produces a dragstart
              whose payload looks exactly like a dragged link. }}
          {{! eslint-disable ember/template-no-nested-interactive }}
          <div id="editable" contenteditable="true">
            <a id="inner" href="https://example.com/adopted">a link</a>
          </div>
          <div
            id="zone"
            {{dDragAndDropTarget adopts=WEB_LINK onDrop=onDrop}}
          >zone</div>
        </template>
      );

      await simulateUnsourcedDrag("#inner", "#zone", {
        dataTransfer: linkTransfer(),
      });

      assert.deepEqual(
        drops,
        [],
        "editing text is not a drag to be repurposed, however link-shaped its payload"
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

    test("a drag the browser started is left alone", async function (assert) {
      const WEB_LINK = {
        type: "web-link",
        match: ({ element }) => Boolean(element.closest("a[href]")),
      };
      const dataTransfer = new DataTransfer();
      dataTransfer.setData("text/uri-list", "https://example.com/adopted");

      await render(
        <template>
          <a id="anchor" href="https://example.com/adopted">a link</a>
          <div id="zone" {{dDragAndDropTarget adopts=WEB_LINK}}>zone</div>
          <div id="nowhere">not a drop target</div>
        </template>
      );

      await dragEvent("#anchor", "dragstart", {
        dataTransfer,
        ...centerOf("#anchor"),
      });

      const event = await dragOverAndReturnEvent("#nowhere", dataTransfer);

      assert.false(
        event.defaultPrevented,
        "an adopted drag carries a payload the page can still use, so dropping it somewhere else stays the browser's business"
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

    test("a drag the browser started is left alone", async function (assert) {
      const WEB_LINK = {
        type: "web-link",
        match: ({ element }) => Boolean(element.closest("a[href]")),
      };
      const dataTransfer = recordingTransfer("all");
      dataTransfer.setData("text/uri-list", "https://example.com/adopted");

      await render(
        <template>
          <a id="anchor" href="https://example.com/adopted">a link</a>
          <div id="zone" {{dDragAndDropTarget adopts=WEB_LINK}}>zone</div>
        </template>
      );

      await dragEvent("#anchor", "dragstart", {
        dataTransfer,
        ...centerOf("#anchor"),
      });

      assert.strictEqual(
        dataTransfer.effectAllowed,
        "all",
        "an adopted drag carries a payload the rest of the page can still take, so what it permits stays the browser's decision"
      );
    });
  });

  module("external auto-scroll", function () {
    function textTransfer() {
      const dataTransfer = new DataTransfer();
      dataTransfer.setData("text/plain", "dropped text");
      return dataTransfer;
    }

    /**
     * Holds a drag near the container's bottom edge across several frames.
     * Auto-scroll runs off its own animation-frame loop and eases in over time,
     * so a single event moves nothing measurable.
     */
    async function hoverNearBottomEdge(selector, dataTransfer) {
      const { left, bottom, width } = find(selector).getBoundingClientRect();
      const point = { clientX: left + width / 2, clientY: bottom - 2 };

      await dragEvent(selector, "dragenter", { dataTransfer, ...point });
      for (let frame = 0; frame < 12; frame++) {
        await dragEvent(selector, "dragover", { dataTransfer, ...point });
      }
    }

    const scroller = <template>
      <div
        id="scroller"
        style="height: 100px; overflow-y: auto"
        {{dDragAndDropExternalTarget accepts="text"}}
        {{dDragAndDropAutoScroll accepts=@accepts}}
      >
        <div style="height: 600px">tall</div>
      </div>
    </template>;

    test("external auto-scroll moves the container for a drag from outside the window", async function (assert) {
      await render(<template><scroller @accepts="text" /></template>);

      await hoverNearBottomEdge("#scroller", textTransfer());

      assert.true(
        find("#scroller").scrollTop > 0,
        "holding a drag against the bottom edge scrolls the container down"
      );
    });

    test("external auto-scroll stays off until a consumer asks for it", async function (assert) {
      await render(<template><scroller /></template>);

      await hoverNearBottomEdge("#scroller", textTransfer());

      assert.strictEqual(
        find("#scroller").scrollTop,
        0,
        "a container that named no external kinds is not scrolled by one"
      );
    });
  });

  module("auto-scroll for an adopted drag", function () {
    const WEB_LINK = {
      type: "web-link",
      match: ({ element }) => Boolean(element.closest("a[href]")),
    };

    function linkTransfer() {
      const dataTransfer = new DataTransfer();
      dataTransfer.setData("text/uri-list", "https://example.com/adopted");
      return dataTransfer;
    }

    /**
     * Starts a drag on an element nothing registered and holds it against the
     * container's bottom edge, the way dragging a link down a sidebar does.
     * Auto-scroll eases in across its own frames, so one event moves nothing.
     */
    async function hoverAdoptedNearBottomEdge(sourceSelector, dataTransfer) {
      await dragEvent(sourceSelector, "dragstart", {
        dataTransfer,
        ...centerOf(sourceSelector),
      });

      const { left, bottom, width } = find("#scroller").getBoundingClientRect();
      const point = { clientX: left + width / 2, clientY: bottom - 2 };

      await dragEvent("#scroller", "dragenter", { dataTransfer, ...point });
      for (let frame = 0; frame < 12; frame++) {
        await dragEvent("#scroller", "dragover", { dataTransfer, ...point });
      }
    }

    const scroller = <template>
      <a id="anchor" href="https://example.com/adopted">a link</a>
      <div id="row" {{dDragAndDropSource type="row"}}>a registered row</div>
      <div
        id="scroller"
        style="height: 100px; overflow-y: auto"
        {{dDragAndDropTarget adopts=WEB_LINK}}
        {{dDragAndDropAutoScroll types=@types}}
      >
        <div style="height: 600px">tall</div>
      </div>
    </template>;

    test("auto-scroll engages for an adopted drag named by its adoption type", async function (assert) {
      await render(<template><scroller @types="web-link" /></template>);

      await hoverAdoptedNearBottomEdge("#anchor", linkTransfer());

      assert.true(
        find("#scroller").scrollTop > 0,
        "a container naming the adoption's own type scrolls for a drag adopted under it, which is the only filter a consumer can write"
      );
    });

    test("auto-scroll named a type ignores an adopted drag of another", async function (assert) {
      await render(<template><scroller @types="card" /></template>);

      await hoverAdoptedNearBottomEdge("#anchor", linkTransfer());

      assert.strictEqual(
        find("#scroller").scrollTop,
        0,
        "matching an adopted drag is still matching a type, not a licence to engage on every adoption"
      );
    });

    test("auto-scroll named an adoption type ignores an ordinary drag", async function (assert) {
      await render(<template><scroller @types="web-link" /></template>);

      await hoverAdoptedNearBottomEdge("#row", linkTransfer());

      assert.strictEqual(
        find("#scroller").scrollTop,
        0,
        "a registered source's own drag is not adopted, so a filter written for the adoption leaves it alone"
      );
    });
  });

  module("nested external targets", function () {
    test("an ancestor drops its indicator once a child becomes deepest", async function (assert) {
      await render(
        <template>
          <div
            id="outer-ext"
            style="height: 100px"
            {{dDragAndDropExternalTarget accepts="files"}}
          >
            outer
            <div
              id="inner-ext"
              {{dDragAndDropExternalTarget accepts="files"}}
            >inner</div>
          </div>
        </template>
      );

      const dataTransfer = new DataTransfer();
      dataTransfer.items.add(new File(["x"], "a.txt", { type: "text/plain" }));
      const outerRect = find("#outer-ext").getBoundingClientRect();

      // No `dragstart`: a drag that begins outside the page is what makes this
      // the external adapter's rather than the element adapter's.
      await dragEvent("#outer-ext", "dragenter", {
        dataTransfer,
        clientX: outerRect.left + 5,
        clientY: outerRect.top + 5,
      });
      await dragEvent("#outer-ext", "dragover", {
        dataTransfer,
        clientX: outerRect.left + 5,
        clientY: outerRect.top + 5,
      });

      assert
        .dom("#outer-ext")
        .hasClass(
          "--drag-over-external",
          "the ancestor paints its indicator while it is the deepest target"
        );

      await dragEvent("#inner-ext", "dragenter", {
        dataTransfer,
        ...centerOf("#inner-ext"),
      });
      await dragEvent("#inner-ext", "dragover", {
        dataTransfer,
        ...centerOf("#inner-ext"),
      });

      assert
        .dom("#inner-ext")
        .hasClass("--drag-over-external", "the child takes the indicator");
      assert
        .dom("#outer-ext")
        .doesNotHaveClass(
          "--drag-over-external",
          "and the ancestor gives it up, so only one zone is lit at a time"
        );
    });

    test("an external ancestor that never received an enter receives no leave", async function (assert) {
      const events = [];
      const onOuterEnter = () => events.push("outer:enter");
      const onOuterLeave = () => events.push("outer:leave");
      // The deepest target is the positive control, as in the element target's
      // equivalent: without it, dispatching no lifecycle callback at all would
      // satisfy the assertion below.
      const onInnerEnter = () => events.push("inner:enter");
      const onInnerLeave = () => events.push("inner:leave");

      await render(
        <template>
          <div
            id="outer-ext"
            style="height: 100px"
            {{dDragAndDropExternalTarget
              accepts="files"
              onDragEnter=onOuterEnter
              onDragLeave=onOuterLeave
            }}
          >
            outer
            <div
              id="inner-ext"
              {{dDragAndDropExternalTarget
                accepts="files"
                onDragEnter=onInnerEnter
                onDragLeave=onInnerLeave
              }}
            >inner</div>
          </div>
          <div
            id="away-ext"
            {{dDragAndDropExternalTarget accepts="files"}}
          >away</div>
        </template>
      );

      const dataTransfer = new DataTransfer();
      dataTransfer.items.add(new File(["x"], "a.txt", { type: "text/plain" }));

      // Straight onto the child, so the ancestor is in the stack but never the
      // deepest and so never forwards an enter.
      await dragEvent("#inner-ext", "dragenter", {
        dataTransfer,
        ...centerOf("#inner-ext"),
      });
      await dragEvent("#inner-ext", "dragover", {
        dataTransfer,
        ...centerOf("#inner-ext"),
      });
      await dragEvent("#away-ext", "dragenter", {
        dataTransfer,
        ...centerOf("#away-ext"),
      });
      await dragEvent("#away-ext", "dragover", {
        dataTransfer,
        ...centerOf("#away-ext"),
      });

      assert.deepEqual(
        events,
        ["inner:enter", "inner:leave"],
        "the deepest target is entered and left as a pair, and the ancestor that was never entered is never left"
      );
    });

    test("an external target that becomes deepest without a fresh enter is entered and left", async function (assert) {
      const events = [];
      let drags = 0;

      const onOuterEnter = () => events.push("outer:enter");
      const onOuterDrag = () => drags++;
      const onOuterLeave = () => events.push("outer:leave");

      await render(
        <template>
          <div
            id="outer-ext"
            style="height: 100px"
            {{dDragAndDropExternalTarget
              accepts="files"
              onDragEnter=onOuterEnter
              onDrag=onOuterDrag
              onDragLeave=onOuterLeave
            }}
          >
            outer
            <div
              id="inner-ext"
              {{dDragAndDropExternalTarget accepts="files"}}
            >inner</div>
          </div>
          <div
            id="away-ext"
            {{dDragAndDropExternalTarget accepts="files"}}
          >away</div>
        </template>
      );

      const dataTransfer = new DataTransfer();
      dataTransfer.items.add(new File(["x"], "a.txt", { type: "text/plain" }));
      const outerRect = find("#outer-ext").getBoundingClientRect();

      // Onto the child first, so the ancestor joins the hierarchy while the
      // child is deepest and its own enter is swallowed.
      await dragEvent("#inner-ext", "dragenter", {
        dataTransfer,
        ...centerOf("#inner-ext"),
      });
      await dragEvent("#inner-ext", "dragover", {
        dataTransfer,
        ...centerOf("#inner-ext"),
      });

      // Back onto the ancestor's own area. It becomes deepest without a fresh
      // enter, because it never left the hierarchy.
      await dragEvent("#outer-ext", "dragover", {
        dataTransfer,
        clientX: outerRect.left + 5,
        clientY: outerRect.top + 5,
      });

      await dragEvent("#away-ext", "dragenter", {
        dataTransfer,
        ...centerOf("#away-ext"),
      });
      await dragEvent("#away-ext", "dragover", {
        dataTransfer,
        ...centerOf("#away-ext"),
      });

      assert.true(
        drags > 0,
        "the ancestor was told about the drag once it was the deepest target"
      );
      assert.deepEqual(
        events,
        ["outer:enter", "outer:leave"],
        "so it is entered when it takes over and left when it gives up, matching the element target"
      );
    });

    test("an external ancestor superseded by a child is left before the drop lands", async function (assert) {
      const events = [];
      const onOuterEnter = () => events.push("outer:enter");
      const onOuterLeave = () => events.push("outer:leave");
      const onInnerDrop = () => events.push("inner:drop");

      await render(
        <template>
          <div
            id="outer-ext"
            style="height: 100px"
            {{dDragAndDropExternalTarget
              accepts="files"
              onDragEnter=onOuterEnter
              onDragLeave=onOuterLeave
            }}
          >
            outer
            <div
              id="inner-ext"
              {{dDragAndDropExternalTarget accepts="files" onDrop=onInnerDrop}}
            >inner</div>
          </div>
        </template>
      );

      const dataTransfer = new DataTransfer();
      dataTransfer.items.add(new File(["x"], "a.txt", { type: "text/plain" }));
      const outerRect = find("#outer-ext").getBoundingClientRect();

      // The ancestor's own area first, so it is genuinely entered.
      await dragEvent("#outer-ext", "dragenter", {
        dataTransfer,
        clientX: outerRect.left + 5,
        clientY: outerRect.top + 5,
      });
      await dragEvent("#outer-ext", "dragover", {
        dataTransfer,
        clientX: outerRect.left + 5,
        clientY: outerRect.top + 5,
      });

      await dragEvent("#inner-ext", "dragenter", {
        dataTransfer,
        ...centerOf("#inner-ext"),
      });
      await dragEvent("#inner-ext", "dragover", {
        dataTransfer,
        ...centerOf("#inner-ext"),
      });
      await dragEvent("#inner-ext", "drop", {
        dataTransfer,
        ...centerOf("#inner-ext"),
      });

      assert.deepEqual(
        events,
        ["outer:enter", "outer:leave", "inner:drop"],
        "the ancestor is left as soon as the child takes over, so a drop never lands with its enter still open"
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
});
