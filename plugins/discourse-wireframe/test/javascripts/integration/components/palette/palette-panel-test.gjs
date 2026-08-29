import {
  click,
  doubleClick,
  fillIn,
  render,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import PalettePanel from "discourse/plugins/discourse-wireframe/discourse/components/editor/palette/palette-panel";

// Replace an already-instantiated wireframe service with a plain stub. The real
// services are booted into the test owner, so a bare `register` won't swap the
// cached singleton — unregister first, then register the stub as-is.
function stubService(owner, name, stub) {
  owner.unregister(`service:${name}`);
  owner.register(`service:${name}`, stub, { instantiate: false });
}

module(
  "Integration | discourse-wireframe | Component | palette-panel",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders at least one entry per registered starter block", async function (assert) {
      await render(<template><PalettePanel /></template>);

      // The starter blocks plus any core built-ins (`head`, `group`)
      // auto-register before tests run, so the palette should have a
      // non-trivial number of entries.
      assert.dom(".wireframe-block-row").exists();
      const entries = document.querySelectorAll(".wireframe-block-row");
      assert.true(entries.length >= 8);
    });

    test("filters by the search input", async function (assert) {
      await render(<template><PalettePanel /></template>);

      await fillIn(".wireframe-palette__search", "paragraph");
      assert
        .dom(".wireframe-block-row")
        .exists({ count: 1 }, "only Paragraph matches 'paragraph'");
      assert.dom(".wireframe-block-row").hasText(/Paragraph/);
    });

    test("renders the empty state when no entries match", async function (assert) {
      await render(<template><PalettePanel /></template>);

      await fillIn(".wireframe-palette__search", "definitely-no-match");
      assert.dom(".wireframe-block-row").doesNotExist();
      assert.dom(".wireframe-palette .panel-empty").exists();
    });

    test("groups rows under category section headers", async function (assert) {
      await render(<template><PalettePanel /></template>);

      const headers = [
        ...document.querySelectorAll(".wireframe-palette__section-header"),
      ].map((el) => el.textContent.trim());
      assert.true(headers.includes("Content"));
      assert.true(headers.includes("Layout"));
    });

    test("offers the default blocks as Recent until the layout has taught it anything", async function (assert) {
      await render(<template><PalettePanel /></template>);

      const recentNames = [
        ...document.querySelectorAll(
          ".wireframe-palette__recent .wireframe-block-tile"
        ),
      ].map((el) => el.dataset.blockName);
      assert.deepEqual(recentNames.slice(0, 2), ["paragraph", "heading"]);
      assert.strictEqual(recentNames.length, 6, "the group is full");
    });

    test("tops Recent up with the block types the layout uses most", async function (assert) {
      this.owner.lookup("service:wireframe-publish-target").setActiveTheme(7);
      this.owner.lookup("service:wireframe-recent-blocks").record("icon");
      stubService(this.owner, "wireframe-layout-query", {
        editableOutlets: ["homepage-blocks"],
        // The root layout wraps the content; only its children count.
        readResolvedLayout: () => [
          {
            block: "layout",
            children: [
              { block: "callout" },
              { block: "list", children: [{ block: "callout" }] },
              { block: "quote" },
            ],
          },
        ],
        blockNameOf: (entry) => entry.block,
        findEntryAndOutletSync: () => null,
        isGridContainer: () => false,
        isGridCellEntry: () => false,
      });

      await render(<template><PalettePanel /></template>);

      const recentNames = [
        ...document.querySelectorAll(
          ".wireframe-palette__recent .wireframe-block-tile"
        ),
      ].map((el) => el.dataset.blockName);
      assert.deepEqual(
        recentNames,
        ["icon", "callout", "list", "quote", "paragraph", "heading"],
        "inserted first, then most used, then defaults, six in all"
      );
    });

    test("each row carries the block's description", async function (assert) {
      await render(<template><PalettePanel /></template>);

      await fillIn(".wireframe-palette__search", "paragraph");
      assert
        .dom(".wireframe-block-row .wireframe-block-row__description")
        .hasAnyText("the description is on the row, not hover-only");
    });

    test("lists the blocks inserted most recently first, newest at the top", async function (assert) {
      this.owner.lookup("service:wireframe-publish-target").setActiveTheme(7);
      const recent = this.owner.lookup("service:wireframe-recent-blocks");
      recent.record("paragraph");
      recent.record("heading");

      await render(<template><PalettePanel /></template>);

      const headers = [
        ...document.querySelectorAll(".wireframe-palette__section-header"),
      ].map((el) => el.textContent.trim());
      assert.strictEqual(headers[0], "Recent");
      const recentNames = [
        ...document.querySelectorAll(
          ".wireframe-palette__recent .wireframe-block-tile"
        ),
      ].map((el) => el.dataset.blockName);
      assert.deepEqual(
        recentNames.slice(0, 2),
        ["heading", "paragraph"],
        "recent blocks are compact tiles, newest first"
      );
      assert
        .dom(".wireframe-block-row[data-block-name='heading']")
        .exists("a recent block still appears in its category too");

      await fillIn(".wireframe-palette__search", "heading");
      assert
        .dom(".wireframe-palette__section-header")
        .doesNotIncludeText("Recent", "the group hides while searching");
      assert
        .dom(".wireframe-palette__recent")
        .doesNotExist("so a match is listed once");
    });

    test("arrowing down from the search marks a row active and Enter inserts it", async function (assert) {
      let lastInsert = null;
      stubService(this.owner, "wireframe-selection", {
        selectedBlockKey: "para-1",
        selectedBlockData: {
          outletName: "homepage",
          metadata: { isContainer: false },
        },
      });
      stubService(this.owner, "wireframe-layout-query", {
        editableOutlets: [],
        findEntryAndOutletSync: () => ({ entry: { block: "paragraph" } }),
        isGridContainer: () => false,
        isGridCellEntry: () => false,
      });
      stubService(this.owner, "wireframe-block-mutations", {
        insertBlock: (args) => (lastInsert = args),
      });

      await render(<template><PalettePanel /></template>);
      await fillIn(".wireframe-palette__search", "paragraph");
      await triggerKeyEvent(
        ".wireframe-palette__search",
        "keydown",
        "ArrowDown"
      );
      assert
        .dom(".wireframe-block-row.--active")
        .exists({ count: 1 }, "the keyboard cursor lands on the first match");
      assert.dom(".wireframe-palette__search").isFocused();

      await triggerKeyEvent(".wireframe-palette__search", "keydown", "Enter");
      assert.strictEqual(lastInsert?.blockName, "paragraph");
    });

    test("a single click on a row is a no-op (insert is double-click)", async function (assert) {
      await render(<template><PalettePanel /></template>);

      await click(".wireframe-block-row");
      assert
        .dom(".wireframe-palette__hint")
        .doesNotExist("a stray single click neither inserts nor hints");
    });

    test("double-clicking a row with nothing selected shows a hint, not a silent no-op", async function (assert) {
      await render(<template><PalettePanel /></template>);

      await doubleClick(".wireframe-block-row");
      assert
        .dom(".wireframe-palette__hint")
        .exists("a hint explains why nothing was inserted");
    });

    test("activating a row while a grid is selected hints instead of inserting wrong", async function (assert) {
      let inserted = 0;
      stubService(this.owner, "wireframe-selection", {
        selectedBlockKey: "grid-1",
        selectedBlockData: { outletName: "o", metadata: { isContainer: true } },
      });
      stubService(this.owner, "wireframe-layout-query", {
        editableOutlets: [],
        findEntryAndOutletSync: () => ({ entry: { block: "layout" } }),
        isGridContainer: () => true,
        isGridCellEntry: () => false,
      });
      stubService(this.owner, "wireframe-block-mutations", {
        insertBlock: () => (inserted += 1),
      });

      await render(<template><PalettePanel /></template>);
      await doubleClick(".wireframe-block-row");

      assert.strictEqual(inserted, 0, "does not insert into a grid blindly");
      assert
        .dom(".wireframe-palette__hint")
        .exists("points the user at the cell + instead");
    });

    test("activating a row while a plain block is selected inserts after it", async function (assert) {
      let lastInsert = null;
      stubService(this.owner, "wireframe-selection", {
        selectedBlockKey: "para-1",
        selectedBlockData: {
          outletName: "homepage",
          metadata: { isContainer: false },
        },
      });
      stubService(this.owner, "wireframe-layout-query", {
        editableOutlets: [],
        findEntryAndOutletSync: () => ({ entry: { block: "paragraph" } }),
        isGridContainer: () => false,
        isGridCellEntry: () => false,
      });
      stubService(this.owner, "wireframe-block-mutations", {
        insertBlock: (args) => (lastInsert = args),
      });

      await render(<template><PalettePanel /></template>);
      await doubleClick(".wireframe-block-row");

      assert.strictEqual(
        lastInsert?.position,
        "after",
        "inserts after the selected block"
      );
      assert.strictEqual(lastInsert?.targetKey, "para-1");
      assert.strictEqual(lastInsert?.targetOutletName, "homepage");
    });
  }
);
