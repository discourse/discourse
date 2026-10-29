import {
  click,
  doubleClick,
  fillIn,
  render,
  triggerKeyEvent,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import PalettePanel from "discourse/plugins/discourse-wireframe/discourse/components/editor/palette/palette-panel";
import { buildBlockPalette } from "discourse/plugins/discourse-wireframe/discourse/lib/palette";

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

    test("deferred blocks stay registered but are absent from insertion choices", async function (assert) {
      const blocks = this.owner.lookup("service:blocks");
      const deferred = [
        "accordion-item",
        "cta-banner",
        "wf:cta-actions",
        "table",
        "accordion",
        "list",
        "link-list",
        "stats",
        "quote",
        "icon",
        "video",
        "embed",
        "head",
        "featured-badges",
        "category-banner",
        "tag-banner",
      ];
      const palette = buildBlockPalette(blocks);

      await render(<template><PalettePanel /></template>);

      for (const name of deferred) {
        assert.true(Boolean(blocks.getBlock(name)), `${name} stays registered`);
        assert.false(
          palette.some((entry) => entry.blockName === name),
          `${name} is absent from the shared insertion catalogue`
        );
        assert
          .dom(`[data-block-name='${name}']`)
          .doesNotExist(`${name} is absent from the palette groups`);
      }

      await fillIn(".wireframe-palette__search", "CTA");
      assert
        .dom(".wireframe-block-row")
        .doesNotExist("search does not offer deferred calls to action");
      assert.true(
        palette.some((entry) => entry.blockName === "card"),
        "Card remains available"
      );
      assert.true(
        palette.some((entry) => entry.blockName === "button-link"),
        "individual action buttons remain available"
      );
      for (const name of [
        "topic-card",
        "featured-categories",
        "featured-tags",
        "featured-users",
      ]) {
        assert.true(
          palette.some((entry) => entry.blockName === name),
          `${name} remains available despite partial editor support`
        );
      }
    });

    test("static Card catalogue offers one leaf without competing legacy registrations", async function (assert) {
      await render(<template><PalettePanel /></template>);
      await fillIn(".wireframe-palette__search", "card");

      assert
        .dom(".wireframe-block-row[data-block-name='card']")
        .exists(
          { count: 1 },
          "Card has one insertion choice, not presentation variants"
        );
      assert
        .dom(".wireframe-block-row[data-block-name='media-card']")
        .doesNotExist("media and identity use Card");
      assert
        .dom(".wireframe-block-row[data-block-name='wf:cta-card']")
        .doesNotExist("static calls to action use Card");

      const blocks = this.owner.lookup("service:blocks");
      assert.false(
        Boolean(blocks.getBlock("media-card")),
        "media-card is not registered"
      );
      assert.false(
        Boolean(blocks.getBlock("wf:cta-card")),
        "CTA card is not registered"
      );
    });

    test("renders at least one entry per registered starter block", async function (assert) {
      await render(<template><PalettePanel /></template>);

      // The starter blocks plus any core built-ins (`head`, `group`)
      // auto-register before tests run, so the palette should have a
      // non-trivial number of entries.
      assert.dom(".wireframe-block-row").exists();
      const entries = document.querySelectorAll(".wireframe-block-row");
      assert.true(entries.length >= 8);
    });

    test("palette variants replace the generic layout entry", async function (assert) {
      await render(<template><PalettePanel /></template>);

      const variants = [
        ...document.querySelectorAll(
          ".wireframe-block-row[data-block-name='layout']"
        ),
      ];
      assert.deepEqual(
        variants.map((element) => ({
          id: element.dataset.paletteId,
          label: element.getAttribute("aria-label"),
        })),
        [
          { id: "layout:stack", label: "Stack" },
          { id: "layout:row", label: "Row" },
          { id: "layout:grid", label: "Grid" },
        ],
        "the three creation intents share one underlying block"
      );
      assert
        .dom(".wireframe-block-row[aria-label='Layout']")
        .doesNotExist("the ambiguous generic entry is omitted");
    });

    test("layout palette variants render distinct SVG thumbnails", async function (assert) {
      await render(<template><PalettePanel /></template>);
      await waitUntil(
        () =>
          document.querySelectorAll(
            ".wireframe-block-row[data-palette-id='layout:stack'] svg rect"
          ).length > 0
      );

      assert
        .dom(
          ".wireframe-block-row[data-palette-id='layout:stack'] svg rect[width='80']"
        )
        .exists({ count: 3 }, "Stack shows three horizontal blocks");
      assert
        .dom(
          ".wireframe-block-row[data-palette-id='layout:row'] svg rect[height='48']"
        )
        .exists({ count: 3 }, "Row shows three vertical blocks");
      assert
        .dom(".wireframe-block-row[data-palette-id='layout:grid'] svg rect")
        .exists({ count: 4 }, "Grid shows an asymmetric cell arrangement");
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
      assert.deepEqual(
        headers,
        ["Layout", "Text", "Media", "Cards & actions", "Community"],
        "structure first, the rest in the declared order, no invented group"
      );
    });

    test("rows in a group lead with the blocks reached for first, then A-Z", async function (assert) {
      await render(<template><PalettePanel /></template>);

      const headers = [
        ...document.querySelectorAll(".wireframe-palette__section-header"),
      ];
      const text = headers.find((el) => el.textContent.trim() === "Text");
      const names = [];
      for (
        let el = text.nextElementSibling;
        el && el.classList.contains("wireframe-block-row");
        el = el.nextElementSibling
      ) {
        names.push(el.dataset.blockName);
      }
      assert.deepEqual(names.slice(0, 3), ["heading", "paragraph", "callout"]);
    });

    test("each row carries the block's description", async function (assert) {
      await render(<template><PalettePanel /></template>);

      await fillIn(".wireframe-palette__search", "paragraph");
      assert
        .dom(".wireframe-block-row .wireframe-block-row__description")
        .hasAnyText("the description is on the row, not hover-only");
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

    test("a layout variant inserts the shared block with its mode defaults", async function (assert) {
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
      await fillIn(".wireframe-palette__search", "grid");
      await doubleClick(".wireframe-block-row[data-palette-id='layout:grid']");

      assert.deepEqual(
        {
          blockName: lastInsert?.blockName,
          defaultArgs: lastInsert?.defaultArgs,
        },
        {
          blockName: "layout",
          defaultArgs: { mode: "grid" },
        }
      );
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
