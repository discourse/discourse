import { hash } from "@ember/helper";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import containerDropTarget from "discourse/plugins/discourse-wireframe/discourse/modifiers/container-drop-target";
import { simulateDrag } from "../../helpers/drag-helpers";

// End-to-end gesture coverage for the stack/row drop pipeline: a real PDND
// drag from a palette source, over the `containerDropTarget`, through
// `computeDescriptor` → `wireframeDragOverlay.claimSlotInsert` → (drop) →
// `wireframeDragOverlay.dispatch`. This guards the WHOLE chain — if the target
// stopped registering, or the descriptor/dispatch wiring broke, no dispatch
// would be captured.
//
//   stack container (y-axis)         palette source
//   ┌───────────────┐  A             ┌──────────┐
//   ├───────────────┤  ◆ seam        │ paragraph│ ──drag──▶ onto the A|B seam
//   │               │  B             └──────────┘
//   └───────────────┘
//   expect: insertBlock { targetKey: "B", position: "before" } (one between-zone)
module(
  "Integration | discourse-wireframe | stack drag gesture",
  function (hooks) {
    setupRenderingTest(hooks);

    // Minimal stand-in for the editor service: the `computeDescriptor` surface
    // (wireframe) plus the overlay coordinator's claim/dispatch. `dispatch`
    // replays the dispatch the claimed slot-insert carried, captured at drop.
    function stubWireframe(owner, onDispatch) {
      const wireframe = owner.lookup("service:wireframe");
      const dropAuthority = owner.lookup("service:wireframe-drop-authority");
      const overlay = owner.lookup("service:wireframe-drag-overlay");
      let captured = null;

      // Several of these are `@action`-decorated on the real service, which
      // installs a getter-only accessor on the prototype — a plain assignment
      // would throw in strict mode. Define own data properties instead so the
      // stub shadows both plain methods and decorated accessors uniformly.
      const stub = (obj, name, fn) =>
        Object.defineProperty(obj, name, {
          value: fn,
          configurable: true,
          writable: true,
        });

      stub(wireframe.wireframeLayoutQuery, "findEntryAndOutletSync", (key) => ({
        entry: { block: key, id: null },
        outletName: "o",
      }));
      stub(wireframe.wireframeLayoutQuery, "lookupBlockMetadata", () => ({
        isContainer: false,
      }));
      stub(
        wireframe.wireframeLayoutQuery,
        "lookupBlockDisplayName",
        (block) => block
      );
      stub(dropAuthority, "canInsertBlockAt", () => true);
      stub(dropAuthority, "canDropAt", () => true);
      stub(wireframe.wireframeLayoutQuery, "isOutletRoot", () => false);
      stub(overlay, "claimSlotInsert", (descriptor) => {
        captured = descriptor;
        return () => (captured = null);
      });
      stub(overlay, "dispatch", () => {
        if (captured?.dispatch) {
          onDispatch(captured.dispatch);
        }
      });

      return wireframe;
    }

    const Stack = <template>
      <div
        id="stack"
        style="position: fixed; top: 0; left: 0; width: 200px;"
        {{containerDropTarget
          mode="stack"
          containerKey="layout:1"
          outletName="o"
        }}
      >
        <div class="wireframe-block-chrome-wrapper" style="height: 100px;">
          <div
            class="wireframe-block-chrome"
            data-wf-block-key="A"
            data-wf-block-name="paragraph"
          ></div>
        </div>
        <div class="wireframe-block-chrome-wrapper" style="height: 100px;">
          <div
            class="wireframe-block-chrome"
            data-wf-block-key="B"
            data-wf-block-name="paragraph"
          ></div>
        </div>
      </div>
      <div
        id="palette"
        {{dDragAndDropSource
          type="wf-palette-block"
          data=(hash blockName="paragraph" defaultArgs=(hash))
        }}
      >palette</div>
    </template>;

    test("dragging a palette block onto the A|B seam dispatches a single between-insert", async function (assert) {
      let dispatched = null;
      stubWireframe(this.owner, (d) => (dispatched = d));

      await render(Stack);

      const stack = document.querySelector("#stack");
      const a = stack.children[0].getBoundingClientRect();
      // Cursor on the seam between A and B.
      await simulateDrag({
        source: "#palette",
        target: "#stack",
        clientX: a.left + a.width / 2,
        clientY: a.bottom,
      });

      assert.notStrictEqual(dispatched, null, "the drop dispatched a mutation");
      assert.strictEqual(dispatched.action, "insertBlock", "palette → insert");
      assert.strictEqual(
        dispatched.args.targetKey,
        "B",
        "canonical anchor is the trailing neighbour"
      );
      assert.strictEqual(
        dispatched.args.position,
        "before",
        "one 'between A and B' landing, expressed as before-B"
      );
    });
  }
);
