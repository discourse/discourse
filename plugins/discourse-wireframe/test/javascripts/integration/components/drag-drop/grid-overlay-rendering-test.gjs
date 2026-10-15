import Component from "@glimmer/component";
import {
  find,
  findAll,
  render,
  settled,
  triggerEvent,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import BlockOutlet, {
  _resetOutletLayoutsForTesting,
} from "discourse/blocks/block-outlet";
import Card from "discourse/blocks/builtin/card";
import Layout from "discourse/blocks/builtin/layout";
import Section from "discourse/blocks/builtin/section";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import { setupBlockLayoutDraftsStub } from "../../../helpers/stub-block-layout-drafts";
import { queryOf } from "../../../helpers/wireframe-peers";

// Renders the REAL editor overlay over a grid in edit mode. Unit + service
// tests never mount `GridOverlay`, so a render-time throw in it (a getter that
// errors, an unbound method invoked from the template) tore the component down
// — empty cells vanished and drag-and-drop + resize silently died — without any
// test failing. This suite mounts the overlay so that class of regression fails
// here instead of shipping.

const OUTLET = "main-outlet-blocks";

module(
  "Integration | discourse-wireframe | Card layout editing",
  function (hooks) {
    setupRenderingTest(hooks);
    setupBlockLayoutDraftsStub(hooks);
    hooks.afterEach(() => _resetOutletLayoutsForTesting());

    test("review regression: authored Card allocation survives editor mode changes", async function (assert) {
      withPluginApi((api) =>
        api.renderBlocks(OUTLET, [
          {
            block: Layout,
            args: { mode: "row", autoCollapse: "never" },
            children: [
              {
                block: Card,
                id: "fixed-card",
                args: { title: "Fixed" },
                containerArgs: { row: { flexGrow: 0, alignSelf: "start" } },
              },
              {
                block: Card,
                id: "growing-card",
                args: { title: "Growing", body: "More text. ".repeat(20) },
                containerArgs: { row: { flexGrow: 2, alignSelf: "stretch" } },
              },
            ],
          },
        ])
      );
      const wireframe = this.owner.lookup("service:wireframe-workspace");
      wireframe.siteSettings.wireframe_enabled = true;
      logIn(this.owner);
      await render(
        <template>
          <div style="width: 1080px"><BlockOutlet @name={{OUTLET}} /></div>
        </template>
      );
      for (const mode of ["reader", "editor", "reader again"]) {
        if (mode === "editor") {
          wireframe.enter();
        }
        if (mode === "reader again") {
          wireframe.exit();
        }
        await settled();
        const allocations = findAll(
          ".d-block-layout__flex > [data-block-layout-item='card']"
        );
        assert.strictEqual(
          allocations.length,
          2,
          `${mode}: both Cards keep a logical allocation`
        );
        assert.strictEqual(
          getComputedStyle(allocations[0]).flexGrow,
          "0",
          `${mode}: explicit zero growth is retained`
        );
        assert.strictEqual(
          getComputedStyle(allocations[0]).alignSelf,
          "start",
          `${mode}: the first Card remains non-stretched`
        );
        assert.strictEqual(
          getComputedStyle(allocations[1]).flexGrow,
          "2",
          `${mode}: explicit positive growth is retained`
        );
        assert.strictEqual(
          getComputedStyle(allocations[1]).alignSelf,
          "stretch",
          `${mode}: the second Card remains stretched`
        );
        const fixed = allocations[0].getBoundingClientRect();
        const growing = allocations[1].getBoundingClientRect();
        assert.true(
          growing.width > fixed.width * 1.5,
          `${mode}: spare row width goes to the growing Card`
        );
        assert.true(
          fixed.height < growing.height,
          `${mode}: the non-stretched Card keeps its natural height`
        );
      }
    });

    test("empty Card image prompts stay inside their media instead of covering identity and copy", async function (assert) {
      withPluginApi((api) =>
        api.renderBlocks(OUTLET, [
          {
            block: Layout,
            args: { mode: "stack" },
            children: [
              ...["above", "below"].map((presentation) => ({
                block: Card,
                id: `empty-${presentation}`,
                args: {
                  presentation,
                  title: "A card with its feature image removed",
                  body: "This copy must remain reachable in the editor.",
                  identityEnabled: true,
                  identityName: "Speaker",
                  avatar: { url: "/images/avatar.png" },
                },
              })),
            ],
          },
        ])
      );
      const wireframe = this.owner.lookup("service:wireframe-workspace");
      wireframe.siteSettings.wireframe_enabled = true;
      logIn(this.owner);
      await render(
        <template>
          <div style="width: 480px"><BlockOutlet @name={{OUTLET}} /></div>
        </template>
      );
      wireframe.enter();
      await settled();

      // QUnit does not load plugin admin CSS. Supply its positioning parent;
      // the full-editor system test checks geometry with the real stylesheet.
      for (const chrome of findAll(".wireframe-block-chrome")) {
        chrome.style.position = "relative";
      }
      window.dispatchEvent(new Event("resize"));
      await settled();

      for (const presentation of ["above", "below"]) {
        const card = find(
          `[data-block-id='empty-${presentation}'] .d-block-card`
        );
        const chrome = card.closest(".wireframe-block-chrome");
        const marker = card.querySelector(".d-block-card__image");
        const overlay = chrome.querySelector(
          ".wireframe-image-arg-overlay[data-block-arg='image']"
        );
        assert
          .dom(overlay)
          .exists("the missing feature keeps a reachable upload prompt");
        for (const edge of ["top", "right", "bottom", "left"]) {
          assert.closeTo(
            overlay.getBoundingClientRect()[edge],
            marker.getBoundingClientRect()[edge],
            1,
            `${presentation} ${edge} stays on the feature frame`
          );
        }
      }
    });

    test("real editor wrappers retain Card seams, selection and independent image targets", async function (assert) {
      withPluginApi((api) =>
        api.renderBlocks(OUTLET, [
          {
            block: Section,
            children: [
              {
                block: Layout,
                args: {
                  mode: "grid",
                  columns: 3,
                  rows: 1,
                  autoCollapse: "never",
                },
                children: [
                  {
                    block: Card,
                    id: "short-card",
                    args: {
                      title: "Short story",
                      scale: "compact",
                      image: { url: "/images/avatar.png" },
                      identityEnabled: true,
                      identityName: "Speaker",
                      href: "/short",
                      actionLabel: "Read short story",
                      wholeCard: true,
                    },
                    containerArgs: { grid: { column: "1", row: "1" } },
                  },
                  {
                    block: Card,
                    id: "long-card",
                    args: {
                      title: "A longer story",
                      body: "Long copy. ".repeat(15),
                      scale: "featured",
                      image: { url: "/images/avatar.png" },
                      href: "/long",
                      actionLabel: "Read long story",
                    },
                    containerArgs: { grid: { column: "2 / 4", row: "1" } },
                  },
                ],
              },
            ],
          },
        ])
      );
      const wireframe = this.owner.lookup("service:wireframe-workspace");
      wireframe.siteSettings.wireframe_enabled = true;
      logIn(this.owner);
      await render(
        <template>
          <div style="width: 1080px"><BlockOutlet @name={{OUTLET}} /></div>
        </template>
      );
      wireframe.enter();
      await settled();
      await waitUntil(
        () =>
          findAll(".wireframe-block-chrome-wrapper [data-card-aligned]")
            .length === 2
      );
      const cards = findAll(".d-block-card");
      const media = cards.map((card) =>
        card.querySelector(".d-block-card__media")
      );
      const actions = cards.map((card) =>
        card.querySelector(".d-block-card__actions")
      );
      assert.closeTo(
        media[0].getBoundingClientRect().bottom,
        media[1].getBoundingClientRect().bottom,
        1,
        "editor media seams match through chrome"
      );
      assert.closeTo(
        actions[0].getBoundingClientRect().bottom,
        actions[1].getBoundingClientRect().bottom,
        1,
        "editor action edges match through chrome"
      );
      assert
        .dom(cards[0])
        .hasAttribute(
          "data-card-aligned",
          "",
          "the actual Card is coordinated"
        );
      assert
        .dom(".d-block-card [data-block-arg='image']")
        .exists({ count: 2 }, "both feature images are editable");
      assert
        .dom(".d-block-card [data-block-arg='avatar']")
        .exists(
          { count: 1 },
          "enabled empty portrait has an independent target"
        );
      await triggerEvent(cards[0], "click", { detail: 1 });
      assert
        .dom(cards[0].closest(".wireframe-block-chrome"))
        .hasClass("--selected", "Card remains one selectable leaf");
      assert
        .dom(".wireframe-grid-cell")
        .doesNotExist("alignment creates no extra authored grid cells");
    });
  }
);

@block("grid-overlay-rendering-leaf")
class Leaf extends Component {
  <template>
    <div class="grid-overlay-rendering-leaf">cell</div>
  </template>
}

// A 3×2 grid with one filled cell at (1,1), leaving five unoccupied positions
// the overlay should surface as empty cells.
function seedGrid() {
  withPluginApi((api) =>
    api.renderBlocks(OUTLET, [
      {
        block: Layout,
        args: { mode: "grid", columns: 3, rows: 2 },
        children: [
          {
            block: Leaf,
            containerArgs: { grid: { column: "1", row: "1" } },
          },
        ],
      },
    ])
  );
}

// Seeds the grid, renders the outlet, and enters the editor so `BlockChrome`
// wraps the grid and mounts `GridOverlay`. Returns the editor service.
async function renderGridInEditMode(owner) {
  seedGrid();
  const wireframe = owner.lookup("service:wireframe-workspace");
  wireframe.siteSettings.wireframe_enabled = true;
  logIn(owner);

  await render(<template><BlockOutlet @name={{OUTLET}} /></template>);

  // Activating the editor flips `BlockChrome` into painting chrome, which is
  // what mounts the overlay. Re-settle so the reactive re-render lands.
  wireframe.enter();
  await settled();

  return wireframe;
}

module(
  "Integration | discourse-wireframe | GridOverlay rendering",
  function (hooks) {
    setupRenderingTest(hooks);
    setupBlockLayoutDraftsStub(hooks);

    hooks.afterEach(function () {
      _resetOutletLayoutsForTesting();
    });

    test("renders empty cells and their resize handles over the grid", async function (assert) {
      await renderGridInEditMode(this.owner);

      assert
        .dom(".wireframe-grid-cell")
        .exists(
          { count: 5 },
          "the overlay renders one empty cell per unoccupied grid position — if the overlay throws at render, none appear"
        );

      assert
        .dom(".wireframe-grid-cell .wireframe-block-chrome__resize-handle")
        .exists("an empty cell carries its merge/resize handles");

      assert
        .dom(
          ".wireframe-block-chrome-wrapper.--in-grid-cell .wireframe-block-chrome__resize-handle"
        )
        .exists(
          "a filled grid cell carries its resize handles too (always in the DOM, CSS-gated to hover / selection)"
        );
    });

    test("keeps the inactive resize ghost out of grid layout", async function (assert) {
      await renderGridInEditMode(this.owner);

      assert
        .dom(".wireframe-grid-ghost")
        .hasAttribute(
          "style",
          "display: none;",
          "the hidden preview cannot create an implicit grid track"
        );
    });

    test("selecting reuses each empty cell's DOM instead of rebuilding it", async function (assert) {
      // Guards the keyed `{{#each}}`: the `emptyCells` getter returns new
      // objects every read, so without a stable key a selection change would
      // tear down and rebuild every cell — destroying the resize handle a merge
      // drag just captured the pointer on (the bug that made the drag do
      // nothing).
      const wireframe = await renderGridInEditMode(this.owner);

      assert
        .dom('.wireframe-grid-cell[data-col="2"][data-row="1"]')
        .exists("an empty cell exists before selection changes");
      const before = find('.wireframe-grid-cell[data-col="2"][data-row="1"]');

      // Any selection change recomputes `emptyCells` (it reads the tracked
      // selection). Selecting the grid is enough to trigger the rebuild path.
      const grid = queryOf(wireframe).readResolvedLayout(OUTLET)[0];
      wireframe.wireframeSelection.selectBlock({
        key: `layout:${grid.__stableKey}`,
      });
      await settled();

      const after = find('.wireframe-grid-cell[data-col="2"][data-row="1"]');
      assert.strictEqual(
        before,
        after,
        "the empty cell's DOM node is reused across the selection change, not rebuilt"
      );
    });

    test("releasing a filled cell's resize handle commits through the grid manipulator", async function (assert) {
      // Regression: BlockChrome's `onGridResizeEnd` calls
      // `wireframeGridPlacement.resizeSlot`, so the component must inject that
      // service. It once read `this.wireframeGridPlacement` without an
      // `@service` declaration, so the pointer-up threw and the span-resize
      // silently died. Unit / service tests never mount the chrome, and the
      // missing injection doesn't throw at render — only on the release — so it
      // takes an interaction test through the real handle to catch it.
      const wireframe = await renderGridInEditMode(this.owner);

      const manipulator = this.owner.lookup("service:wireframe-grid-placement");
      const calls = [];
      manipulator.resizeSlot = (args) => calls.push(args);

      const handle = find(
        ".wireframe-block-chrome-wrapper.--in-grid-cell .wireframe-block-chrome__resize-handle"
      );
      const rect = handle.getBoundingClientRect();
      const startX = rect.left + rect.width / 2;
      const startY = rect.top + rect.height / 2;

      // Drive the pointer-drag the handle binds (pointerdown → move → up).
      // Synthetic events ignore the CSS pointer-events gating, so no hover /
      // selection is needed; any move makes the span-resize compute a placement,
      // so the release commits through `resizeSlot`.
      await triggerEvent(handle, "pointerdown", {
        button: 0,
        pointerId: 1,
        clientX: startX,
        clientY: startY,
      });
      await triggerEvent(handle, "pointermove", {
        pointerId: 1,
        clientX: startX + 120,
        clientY: startY + 120,
      });
      await triggerEvent(handle, "pointerup", {
        pointerId: 1,
        clientX: startX + 120,
        clientY: startY + 120,
      });

      assert.strictEqual(
        calls.length,
        1,
        "the release commits the new span through wireframeGridPlacement.resizeSlot"
      );
      const grid = queryOf(wireframe).readResolvedLayout(OUTLET)[0];
      const cellKey = `grid-overlay-rendering-leaf:${grid.children[0].__stableKey}`;
      assert.strictEqual(
        calls[0].slotKey,
        cellKey,
        "the resize targets the dragged cell's slot"
      );
    });
  }
);
