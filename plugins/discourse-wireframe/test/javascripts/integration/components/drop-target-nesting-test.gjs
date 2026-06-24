import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  computeDescriptor,
  isInEdgeBand,
} from "discourse/plugins/discourse-wireframe/discourse/modifiers/container-drop-target";

// These render real DOM at known geometry and drive the EXPORTED resolution
// helpers directly (no drag library), so the actual `computeDescriptor` /
// `isInEdgeBand` code paths run against live `getBoundingClientRect`s. The
// editor scales `#ember-testing`, so every test reads measured rects and
// derives cursor coordinates from THEM rather than hardcoding pixels.

// Minimal stand-in for the editor service. `computeDescriptor` only reaches
// for entry lookup, container-ness, display names, and the insert/drop
// validity gates. Each entry's `block` echoes its key, so `isContainer` and
// display names can key off the block key the markup carries.
function stubWireframe(overrides = {}) {
  return {
    findEntryAndOutletSync: (key) => ({
      entry: { block: key, id: null },
      outletName: "test-outlet",
    }),
    lookupBlockMetadata: () => ({ isContainer: false }),
    lookupBlockDisplayName: (block) => block,
    canInsertBlockAt: () => true,
    canDropAt: () => true,
    ...overrides,
  };
}

const PALETTE = {
  type: "wf-palette-block",
  data: { blockName: "paragraph", defaultArgs: {} },
};

function rectOf(selector) {
  return document.querySelector(selector).getBoundingClientRect();
}

// Cursor at a fraction `t` along the axis of a wrapper's rect, centred on the
// cross axis so we land cleanly inside the projected segment.
function cursorAt(rect, axis, t) {
  return axis === "x"
    ? {
        clientX: rect.left + rect.width * t,
        clientY: rect.top + rect.height / 2,
      }
    : {
        clientX: rect.left + rect.width / 2,
        clientY: rect.top + rect.height * t,
      };
}

module(
  "Integration | discourse-wireframe | drop-target nesting",
  function (hooks) {
    setupRenderingTest(hooks);

    /*
     * Stack (vertical, y-axis) of two leaves.
     *   ┌─────────────┐
     *   │      A      │  idx 0
     *   ├─────────────┤  ← the A|B seam
     *   │      B      │  idx 1
     *   └─────────────┘
     */
    const Stack = <template>
      <div
        id="container"
        style="position: fixed; top: 0; left: 0; width: 200px;"
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
    </template>;

    test("stack: the A|B seam is ONE 'between' zone (last-third-A, seam, first-third-B collapse)", async function (assert) {
      await render(Stack);
      const wireframe = stubWireframe();
      const container = document.querySelector("#container");
      const aWrap = container.children[0].getBoundingClientRect();
      const bWrap = container.children[1].getBoundingClientRect();

      const call = (clientY) =>
        computeDescriptor({
          wireframe,
          container,
          input: { clientX: aWrap.left + aWrap.width / 2, clientY },
          containerKey: "stack",
          outletName: "test-outlet",
          axis: "y",
          source: PALETTE,
        });

      //   ◆ 90% down A   ◆ exact seam   ◆ 10% into B
      const lastThirdA = call(aWrap.top + aWrap.height * 0.9);
      const seam = call(aWrap.bottom);
      const firstThirdB = call(bWrap.top + bWrap.height * 0.1);

      // All three resolve to the identical descriptor — one zone.
      assert.deepEqual(lastThirdA, seam, "last-third-A === seam");
      assert.deepEqual(seam, firstThirdB, "seam === first-third-B");

      // Canonical dispatch: insert BEFORE the trailing neighbour (B).
      assert.strictEqual(seam.kind, "insert");
      assert.strictEqual(seam.dispatch.action, "insertBlock");
      assert.strictEqual(seam.dispatch.args.targetKey, "B");
      assert.strictEqual(seam.dispatch.args.position, "before");
      // Label names BOTH neighbours.
      assert.strictEqual(seam.label, "Add paragraph between A and B");
    });

    test("stack: start and end edges keep before/after semantics", async function (assert) {
      await render(Stack);
      const wireframe = stubWireframe();
      const container = document.querySelector("#container");
      const aWrap = container.children[0].getBoundingClientRect();
      const bWrap = container.children[1].getBoundingClientRect();

      //   ◆ 10% into A → before the first child (gap 0)
      const start = computeDescriptor({
        wireframe,
        container,
        input: cursorAt(aWrap, "y", 0.1),
        containerKey: "stack",
        outletName: "test-outlet",
        axis: "y",
        source: PALETTE,
      });
      assert.strictEqual(start.dispatch.args.targetKey, "A");
      assert.strictEqual(start.dispatch.args.position, "before");
      assert.strictEqual(start.label, "Add paragraph before A");

      //   ◆ 90% down B → after the last child (gap 2)
      const end = computeDescriptor({
        wireframe,
        container,
        input: cursorAt(bWrap, "y", 0.9),
        containerKey: "stack",
        outletName: "test-outlet",
        axis: "y",
        source: PALETTE,
      });
      assert.strictEqual(end.dispatch.args.targetKey, "B");
      assert.strictEqual(end.dispatch.args.position, "after");
      assert.strictEqual(end.label, "Add paragraph after B");
    });

    test("stack: dropping a block onto a seam next to itself is a no-op", async function (assert) {
      await render(Stack);
      const wireframe = stubWireframe();
      const container = document.querySelector("#container");
      const aWrap = container.children[0].getBoundingClientRect();

      //   drag B, hover the A|B seam → B is already there → null
      const descriptor = computeDescriptor({
        wireframe,
        container,
        input: { clientX: aWrap.left + 5, clientY: aWrap.bottom },
        containerKey: "stack",
        outletName: "test-outlet",
        axis: "y",
        source: { type: "wf-block", data: { blockKey: "B" } },
      });
      assert.strictEqual(descriptor, null);
    });

    /*
     * stack → row : a horizontal row nested in a stack. Resolving WITHIN the
     * row uses the x-axis; the same seam-collapse must hold.
     *   ┌─────┬─────┐
     *   │  A  │  B  │   ← drop in the A|B seam → one 'between' zone
     *   └─────┴─────┘
     */
    test("row (x-axis): the A|B seam collapses to one 'between' zone", async function (assert) {
      await render(
        <template>
          <div
            id="container"
            style="position: fixed; top: 0; left: 0; display: flex; height: 60px;"
          >
            <div class="wireframe-block-chrome-wrapper" style="width: 100px;">
              <div
                class="wireframe-block-chrome"
                data-wf-block-key="A"
                data-wf-block-name="paragraph"
              ></div>
            </div>
            <div class="wireframe-block-chrome-wrapper" style="width: 100px;">
              <div
                class="wireframe-block-chrome"
                data-wf-block-key="B"
                data-wf-block-name="paragraph"
              ></div>
            </div>
          </div>
        </template>
      );
      const wireframe = stubWireframe();
      const container = document.querySelector("#container");
      const aWrap = container.children[0].getBoundingClientRect();
      const bWrap = container.children[1].getBoundingClientRect();

      const call = (clientX) =>
        computeDescriptor({
          wireframe,
          container,
          input: { clientX, clientY: aWrap.top + aWrap.height / 2 },
          containerKey: "row",
          outletName: "test-outlet",
          axis: "x",
          source: PALETTE,
        });

      const lastThirdA = call(aWrap.right - aWrap.width * 0.1);
      const seam = call(aWrap.right);
      const firstThirdB = call(bWrap.left + bWrap.width * 0.1);

      assert.deepEqual(lastThirdA, seam);
      assert.deepEqual(seam, firstThirdB);
      assert.strictEqual(seam.dispatch.args.targetKey, "B");
      assert.strictEqual(seam.dispatch.args.position, "before");
      assert.strictEqual(seam.label, "Add paragraph between A and B");
    });

    /*
     * stack → grid : a grid (a container) sits in a stack. Hovering the grid
     * child's MIDDLE third means "drop INTO the grid", not at a seam.
     *   ┌─────────────┐
     *   │ ░░ GRID ░░  │  ← middle third → inside
     *   └─────────────┘
     */
    test("a container child's middle third resolves to 'inside'", async function (assert) {
      await render(
        <template>
          <div
            id="container"
            style="position: fixed; top: 0; left: 0; width: 200px;"
          >
            <div class="wireframe-block-chrome-wrapper" style="height: 120px;">
              <div
                class="wireframe-block-chrome"
                data-wf-block-key="GRID"
                data-wf-block-name="layout"
              ></div>
            </div>
          </div>
        </template>
      );
      // Mark the GRID child as a container so the middle third reads as "into".
      const wireframe = stubWireframe({
        lookupBlockMetadata: (block) => ({ isContainer: block === "GRID" }),
      });
      const container = document.querySelector("#container");
      const wrap = container.children[0].getBoundingClientRect();

      const descriptor = computeDescriptor({
        wireframe,
        container,
        input: cursorAt(wrap, "y", 0.5),
        containerKey: "stack",
        outletName: "test-outlet",
        axis: "y",
        source: PALETTE,
      });
      assert.strictEqual(descriptor.kind, "inside");
      assert.strictEqual(descriptor.dispatch.args.targetKey, "GRID");
      assert.strictEqual(descriptor.dispatch.args.position, "inside");
    });

    /*
     * row → cell : an empty layout-merged-cell child. Its middle third is a REPLACE
     * landing, never a seam.
     */
    test("a layout-merged-cell child's middle third resolves to 'replace'", async function (assert) {
      await render(
        <template>
          <div
            id="container"
            style="position: fixed; top: 0; left: 0; width: 200px;"
          >
            <div class="wireframe-block-chrome-wrapper" style="height: 90px;">
              <div
                class="wireframe-block-chrome"
                data-wf-block-key="CELL"
                data-wf-block-name="layout-merged-cell"
              ></div>
            </div>
          </div>
        </template>
      );
      const wireframe = stubWireframe();
      const container = document.querySelector("#container");
      const wrap = container.children[0].getBoundingClientRect();

      const descriptor = computeDescriptor({
        wireframe,
        container,
        input: cursorAt(wrap, "y", 0.5),
        containerKey: "stack",
        outletName: "test-outlet",
        axis: "y",
        source: PALETTE,
      });
      assert.strictEqual(descriptor.kind, "replace");
      assert.strictEqual(descriptor.dispatch.action, "placeBlockInCell");
      assert.strictEqual(descriptor.dispatch.args.cellKey, "CELL");
    });

    test("a leaf child's middle third has no landing (overlay hidden)", async function (assert) {
      await render(
        <template>
          <div
            id="container"
            style="position: fixed; top: 0; left: 0; width: 200px;"
          >
            <div class="wireframe-block-chrome-wrapper" style="height: 90px;">
              <div
                class="wireframe-block-chrome"
                data-wf-block-key="LEAF"
                data-wf-block-name="paragraph"
              ></div>
            </div>
          </div>
        </template>
      );
      const wireframe = stubWireframe();
      const container = document.querySelector("#container");
      const wrap = container.children[0].getBoundingClientRect();

      const descriptor = computeDescriptor({
        wireframe,
        container,
        input: cursorAt(wrap, "y", 0.5),
        containerKey: "stack",
        outletName: "test-outlet",
        axis: "y",
        source: PALETTE,
      });
      assert.strictEqual(descriptor, null);
    });

    /*
     * Parent fall-through. A nested container chrome defers a drop near its
     * outer edge so it lands as a SIBLING in the enclosing container.
     *   ┌── stack ───────────────┐
     *   │ ┌── row chrome ──────┐ │ ◆ within 12px of the row's edge
     *   │ │  drop falls through │ │   → isInEdgeBand true → stack handles it
     *   │ └────────────────────┘ │
     *   └────────────────────────┘
     */
    test("isInEdgeBand: edge drops defer, interior drops don't", async function (assert) {
      await render(
        <template>
          <div
            id="chrome"
            style="position: fixed; top: 50px; left: 50px; width: 200px; height: 200px;"
          ></div>
        </template>
      );
      const rect = rectOf("#chrome");
      const at = (clientX, clientY) => isInEdgeBand(rect, { clientX, clientY });

      // Centre — comfortably inside → resolve within this container.
      assert.false(at(rect.left + rect.width / 2, rect.top + rect.height / 2));
      // Within 12px of each edge → defer to the parent.
      assert.true(at(rect.left + 2, rect.top + rect.height / 2), "left edge");
      assert.true(at(rect.right - 2, rect.top + rect.height / 2), "right edge");
      assert.true(at(rect.left + rect.width / 2, rect.top + 2), "top edge");
      assert.true(
        at(rect.left + rect.width / 2, rect.bottom - 2),
        "bottom edge"
      );
    });

    /*
     * Noun-framed container (e.g. a carousel). The container carries
     * `data-wf-child-noun` / `-plural`, so drop messages name positions in
     * slide terms by 1-based ordinal instead of by the neighbour's block name.
     *   ┌─────┬─────┬─────┐
     *   │  A  │  B  │  C  │
     *   └─────┴─────┴─────┘
     */
    const Slides = <template>
      <div
        id="container"
        data-wf-child-noun="slide"
        data-wf-child-noun-plural="slides"
        style="position: fixed; top: 0; left: 0; display: flex; height: 60px;"
      >
        <div class="wireframe-block-chrome-wrapper" style="width: 100px;">
          <div
            class="wireframe-block-chrome"
            data-wf-block-key="A"
            data-wf-block-name="paragraph"
          ></div>
        </div>
        <div class="wireframe-block-chrome-wrapper" style="width: 100px;">
          <div
            class="wireframe-block-chrome"
            data-wf-block-key="B"
            data-wf-block-name="paragraph"
          ></div>
        </div>
        <div class="wireframe-block-chrome-wrapper" style="width: 100px;">
          <div
            class="wireframe-block-chrome"
            data-wf-block-key="C"
            data-wf-block-name="paragraph"
          ></div>
        </div>
      </div>
    </template>;

    test("noun-framed: an interior boundary names both slides by ordinal", async function (assert) {
      await render(Slides);
      const wireframe = stubWireframe();
      const container = document.querySelector("#container");
      const aWrap = container.children[0].getBoundingClientRect();

      const seam = computeDescriptor({
        wireframe,
        container,
        input: { clientX: aWrap.right, clientY: aWrap.top + aWrap.height / 2 },
        containerKey: "carousel",
        outletName: "test-outlet",
        axis: "x",
        source: PALETTE,
      });

      assert.strictEqual(
        seam.label,
        "Add paragraph in a new slide between slides 1 and 2"
      );
      assert.strictEqual(seam.dispatch.args.targetKey, "B");
      assert.strictEqual(seam.dispatch.args.position, "before");
    });

    test("noun-framed: the end edge names the slide ordinal and block", async function (assert) {
      await render(Slides);
      const wireframe = stubWireframe();
      const container = document.querySelector("#container");
      const cWrap = container.children[2].getBoundingClientRect();

      const end = computeDescriptor({
        wireframe,
        container,
        input: cursorAt(cWrap, "x", 0.9),
        containerKey: "carousel",
        outletName: "test-outlet",
        axis: "x",
        source: PALETTE,
      });

      assert.strictEqual(
        end.label,
        "Add paragraph in a new slide after slide 3"
      );
      assert.strictEqual(end.dispatch.args.targetKey, "C");
      assert.strictEqual(end.dispatch.args.position, "after");
    });

    test("noun-framed: nesting into a slide keeps the dragged block's name", async function (assert) {
      await render(
        <template>
          <div
            id="container"
            data-wf-child-noun="slide"
            data-wf-child-noun-plural="slides"
            style="position: fixed; top: 0; left: 0; display: flex; height: 60px;"
          >
            <div class="wireframe-block-chrome-wrapper" style="width: 100px;">
              <div
                class="wireframe-block-chrome"
                data-wf-block-key="S1"
                data-wf-block-name="layout"
              ></div>
            </div>
          </div>
        </template>
      );
      const wireframe = stubWireframe({
        lookupBlockMetadata: (block) => ({ isContainer: block === "S1" }),
      });
      const container = document.querySelector("#container");
      const wrap = container.children[0].getBoundingClientRect();

      const descriptor = computeDescriptor({
        wireframe,
        container,
        input: cursorAt(wrap, "x", 0.5),
        containerKey: "carousel",
        outletName: "test-outlet",
        axis: "x",
        source: PALETTE,
      });

      assert.strictEqual(descriptor.kind, "inside");
      assert.strictEqual(descriptor.label, "Add paragraph into slide 1");
    });
  }
);
