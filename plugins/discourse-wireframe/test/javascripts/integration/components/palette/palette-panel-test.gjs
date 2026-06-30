import { click, doubleClick, fillIn, render } from "@ember/test-helpers";
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
      assert.dom(".wireframe-block-tile").exists();
      const entries = document.querySelectorAll(".wireframe-block-tile");
      assert.true(entries.length >= 8);
    });

    test("filters by the search input", async function (assert) {
      await render(<template><PalettePanel /></template>);

      await fillIn(".wireframe-palette__search", "paragraph");
      assert
        .dom(".wireframe-block-tile")
        .exists({ count: 1 }, "only Paragraph matches 'paragraph'");
      assert.dom(".wireframe-block-tile").hasText(/Paragraph/);
    });

    test("renders the empty state when no entries match", async function (assert) {
      await render(<template><PalettePanel /></template>);

      await fillIn(".wireframe-palette__search", "definitely-no-match");
      assert.dom(".wireframe-block-tile").doesNotExist();
      assert.dom(".wireframe-palette .panel-empty").exists();
    });

    test("groups tiles under category section headers", async function (assert) {
      await render(<template><PalettePanel /></template>);

      // The chip row is gone; category section headers organize the grid.
      const headers = [
        ...document.querySelectorAll(".wireframe-palette__section-header"),
      ].map((el) => el.textContent.trim());
      assert.true(headers.includes("Content"));
      assert.true(headers.includes("Layout"));
    });

    test("a single click on a sidebar tile is a no-op (insert is double-click)", async function (assert) {
      await render(<template><PalettePanel /></template>);

      await click(".wireframe-block-tile");
      assert
        .dom(".wireframe-palette__hint")
        .doesNotExist("a stray single click neither inserts nor hints");
    });

    test("double-clicking a tile with nothing selected shows a hint, not a silent no-op", async function (assert) {
      await render(<template><PalettePanel /></template>);

      await doubleClick(".wireframe-block-tile");
      assert
        .dom(".wireframe-palette__hint")
        .exists("a hint explains why nothing was inserted");
    });

    test("activating a tile while a grid is selected hints instead of inserting wrong", async function (assert) {
      let inserted = 0;
      stubService(this.owner, "wireframe-selection", {
        selectedBlockKey: "grid-1",
        selectedBlockData: { outletName: "o", metadata: { isContainer: true } },
      });
      stubService(this.owner, "wireframe-layout-query", {
        findEntryAndOutletSync: () => ({ entry: { block: "layout" } }),
        isGridContainer: () => true,
        isGridCellEntry: () => false,
      });
      stubService(this.owner, "wireframe-block-mutations", {
        insertBlock: () => (inserted += 1),
      });

      await render(<template><PalettePanel /></template>);
      await doubleClick(".wireframe-block-tile");

      assert.strictEqual(inserted, 0, "does not insert into a grid blindly");
      assert
        .dom(".wireframe-palette__hint")
        .exists("points the user at the cell + instead");
    });

    test("activating a tile while a plain block is selected inserts after it", async function (assert) {
      let lastInsert = null;
      stubService(this.owner, "wireframe-selection", {
        selectedBlockKey: "para-1",
        selectedBlockData: {
          outletName: "homepage",
          metadata: { isContainer: false },
        },
      });
      stubService(this.owner, "wireframe-layout-query", {
        findEntryAndOutletSync: () => ({ entry: { block: "paragraph" } }),
        isGridContainer: () => false,
        isGridCellEntry: () => false,
      });
      stubService(this.owner, "wireframe-block-mutations", {
        insertBlock: (args) => (lastInsert = args),
      });

      await render(<template><PalettePanel /></template>);
      await doubleClick(".wireframe-block-tile");

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
