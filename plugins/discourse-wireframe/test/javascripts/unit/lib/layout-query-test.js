import Component from "@glimmer/component";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import { LAYOUT_SOURCE } from "discourse/blocks/block-outlet";
import LayoutQuery, {
  OUTLET_STATE,
} from "discourse/plugins/discourse-wireframe/discourse/lib/layout-query";

// Decorated test blocks give the metadata-reading methods (`metadataFor`,
// `metadataForName`, `blockNameOf`, `lookupBlock*`, `isComposedComposite`)
// something real to resolve through `getBlockMetadata`.
@block("layout-query-test-tile", {
  displayName: "Tile",
})
class TileBlock extends Component {}

@block("layout-query-test-card", {
  parts: [
    { id: "title", block: "layout-query-test-tile" },
    { id: "body", block: "layout-query-test-tile" },
  ],
})
class CardBlock extends Component {}

// A live entry as it appears in a resolved layout: a `block` reference plus a
// `__stableKey`. `entryKey` derives `${blockName}:${__stableKey}` from this.
function entry({ block: blockRef, stableKey, children, args, containerArgs }) {
  return {
    block: blockRef,
    __stableKey: stableKey,
    ...(children ? { children } : {}),
    ...(args ? { args } : {}),
    ...(containerArgs ? { containerArgs } : {}),
  };
}

// Wraps a layout array in the resolved-layout record shape the lookups iterate
// (`record.layout` for the sync path, `record.validatedLayout` for the async).
function record(layout, { rejects = false } = {}) {
  return {
    layout,
    validatedLayout: rejects
      ? Promise.reject(new Error("invalid layout"))
      : Promise.resolve(layout),
  };
}

// Builds a LayoutQuery over controllable stubs. `layouts` is an outlet->layout
// map; `metaByOutlet` is an outlet->resolved-meta map (provenance);
// `blocksByName` maps a registry name to its class (what the blocks service
// would return).
function buildQuery({
  layouts = {},
  metaByOutlet = {},
  blocksByName = {},
  rejectingOutlets = [],
} = {}) {
  const layoutMap = new Map();
  for (const [outletName, layout] of Object.entries(layouts)) {
    layoutMap.set(
      outletName,
      record(layout, { rejects: rejectingOutlets.includes(outletName) })
    );
  }

  return new LayoutQuery({
    getResolvedLayout: (outletName) => layouts[outletName] ?? null,
    getResolvedLayouts: () => layoutMap,
    getResolvedLayoutMeta: (outletName) => metaByOutlet[outletName] ?? null,
    getBlock: (name) => blocksByName[name] ?? null,
  });
}

module("Unit | Discourse Wireframe | lib:layout-query", function () {
  module("readResolvedLayout", function () {
    test("returns the outlet's layout, or null when absent", function (assert) {
      const layout = [entry({ block: "tile", stableKey: 1 })];
      const query = buildQuery({ layouts: { home: layout } });
      assert.strictEqual(query.readResolvedLayout("home"), layout);
      assert.strictEqual(query.readResolvedLayout("missing"), null);
    });
  });

  module("findEntryAndOutletSync / findEntryByKey", function () {
    test("locates a top-level entry and its outlet", function (assert) {
      const tile = entry({ block: "tile", stableKey: 1 });
      const query = buildQuery({ layouts: { home: [tile] } });
      const located = query.findEntryAndOutletSync("tile:1");
      assert.strictEqual(located.entry, tile);
      assert.strictEqual(located.outletName, "home");
      assert.strictEqual(query.findEntryByKey("tile:1"), tile);
    });

    test("locates a nested entry", function (assert) {
      const child = entry({ block: "tile", stableKey: 2 });
      const container = entry({
        block: "layout",
        stableKey: 1,
        children: [child],
      });
      const query = buildQuery({ layouts: { home: [container] } });
      const located = query.findEntryAndOutletSync("tile:2");
      assert.strictEqual(located.entry, child);
      assert.strictEqual(located.outletName, "home");
    });

    test("returns null when not found, and skips records with no layout", function (assert) {
      const query = buildQuery({ layouts: { home: [] } });
      assert.strictEqual(query.findEntryAndOutletSync("nope:9"), null);
      assert.strictEqual(query.findEntryByKey("nope:9"), null);
    });
  });

  module("findEntryAndOutlet (async)", function () {
    test("locates an entry through the validated layout", async function (assert) {
      const tile = entry({ block: "tile", stableKey: 1 });
      const query = buildQuery({ layouts: { home: [tile] } });
      const located = await query.findEntryAndOutlet("tile:1");
      assert.strictEqual(located.entry, tile);
      assert.strictEqual(located.outletName, "home");
    });

    test("skips a record whose validatedLayout rejects, rather than throwing", async function (assert) {
      const tile = entry({ block: "tile", stableKey: 1 });
      const query = buildQuery({
        layouts: { broken: [], home: [tile] },
        rejectingOutlets: ["broken"],
      });
      const located = await query.findEntryAndOutlet("tile:1");
      assert.strictEqual(located.entry, tile, "found in the healthy outlet");
      assert.strictEqual(located.outletName, "home");
    });

    test("returns null when no outlet resolves the key", async function (assert) {
      const query = buildQuery({
        layouts: { broken: [] },
        rejectingOutlets: ["broken"],
      });
      assert.strictEqual(await query.findEntryAndOutlet("ghost:1"), null);
    });
  });

  module("findEntryParent / isAncestorOf", function () {
    test("findEntryParent returns the immediate parent, null at the root", function (assert) {
      const child = entry({ block: "tile", stableKey: 2 });
      const container = entry({
        block: "layout",
        stableKey: 1,
        children: [child],
      });
      const query = buildQuery({ layouts: { home: [container] } });
      assert.strictEqual(query.findEntryParent("tile:2"), container);
      assert.strictEqual(
        query.findEntryParent("layout:1"),
        null,
        "a top-level entry has no block-level parent"
      );
      assert.strictEqual(query.findEntryParent("missing:9"), null);
    });

    test("isAncestorOf walks the full ancestry path", function (assert) {
      const leaf = entry({ block: "tile", stableKey: 3 });
      const mid = entry({ block: "layout", stableKey: 2, children: [leaf] });
      const root = entry({ block: "layout", stableKey: 1, children: [mid] });
      const query = buildQuery({ layouts: { home: [root] } });
      assert.true(query.isAncestorOf("layout:1", "tile:3"), "grandparent");
      assert.true(query.isAncestorOf("layout:2", "tile:3"), "direct parent");
      assert.false(query.isAncestorOf("tile:3", "layout:1"), "not reversed");
      assert.false(
        query.isAncestorOf("tile:3", "tile:3"),
        "a key is not its own ancestor"
      );
      assert.false(query.isAncestorOf("", "tile:3"), "empty ancestor key");
    });
  });

  module("resolvePartContext", function () {
    test("returns null for a key with no part segment", function (assert) {
      const query = buildQuery({ layouts: { home: [] } });
      assert.strictEqual(query.resolvePartContext("tile:1"), null);
      assert.strictEqual(query.resolvePartContext(""), null);
    });

    test("resolves a part key to its owning composite", function (assert) {
      const composite = entry({ block: "card", stableKey: 7 });
      const query = buildQuery({ layouts: { home: [composite] } });
      const context = query.resolvePartContext("card:7::part::title");
      assert.strictEqual(context.compositeEntry, composite);
      assert.strictEqual(context.outletName, "home");
      assert.deepEqual(context.idPath, ["title"]);
      assert.strictEqual(context.partPath, "title");
    });

    test("handles a plugin block name that itself contains a colon", function (assert) {
      const composite = entry({ block: "theme:my-theme:hero", stableKey: 9 });
      const query = buildQuery({ layouts: { home: [composite] } });
      const context = query.resolvePartContext(
        "theme:my-theme:hero:9::part::actions::part::primary"
      );
      assert.strictEqual(
        context.compositeEntry,
        composite,
        "splits on the LAST colon so the block name's colons are kept"
      );
      assert.deepEqual(context.idPath, ["actions", "primary"]);
      assert.strictEqual(context.partPath, "actions.primary");
    });

    test("returns null when the composite can't be found", function (assert) {
      const query = buildQuery({ layouts: { home: [] } });
      assert.strictEqual(query.resolvePartContext("card:7::part::title"), null);
    });
  });

  module("block metadata / names", function () {
    test("metadataFor reads class metadata, null for string-ref entries", function (assert) {
      const query = buildQuery();
      const decorated = entry({ block: TileBlock, stableKey: 1 });
      assert.strictEqual(
        query.metadataFor(decorated).blockName,
        "layout-query-test-tile"
      );
      assert.strictEqual(
        query.metadataFor(entry({ block: "tile", stableKey: 1 })),
        null,
        "string-ref entries have no class metadata"
      );
      assert.strictEqual(query.metadataFor(null), null);
    });

    test("blockNameOf resolves both string and class refs", function (assert) {
      const query = buildQuery();
      assert.strictEqual(
        query.blockNameOf(entry({ block: "tile", stableKey: 1 })),
        "tile"
      );
      assert.strictEqual(
        query.blockNameOf(entry({ block: TileBlock, stableKey: 1 })),
        "layout-query-test-tile"
      );
      assert.strictEqual(query.blockNameOf(null), null);
    });

    test("metadataForName resolves through the injected block lookup", function (assert) {
      const query = buildQuery({
        blocksByName: { "layout-query-test-tile": TileBlock },
      });
      assert.strictEqual(
        query.metadataForName("layout-query-test-tile").blockName,
        "layout-query-test-tile"
      );
      assert.strictEqual(
        query.metadataForName("unknown"),
        null,
        "unknown name resolves to null"
      );
    });

    test("lookupBlockMetadata handles both a class and a name", function (assert) {
      const query = buildQuery({
        blocksByName: { "layout-query-test-tile": TileBlock },
      });
      assert.strictEqual(
        query.lookupBlockMetadata(TileBlock).blockName,
        "layout-query-test-tile"
      );
      assert.strictEqual(
        query.lookupBlockMetadata("layout-query-test-tile").blockName,
        "layout-query-test-tile"
      );
      assert.strictEqual(query.lookupBlockMetadata("unknown"), null);
    });

    test("lookupBlockDisplayName falls back to the block name", function (assert) {
      const query = buildQuery({
        blocksByName: { "layout-query-test-tile": TileBlock },
      });
      assert.strictEqual(
        query.lookupBlockDisplayName(TileBlock),
        "Tile",
        "uses the declared display name"
      );
      assert.strictEqual(
        query.lookupBlockDisplayName(CardBlock),
        "layout-query-test-card",
        "falls back to the block name when no display name is set"
      );
    });
  });

  module("outletState / isOutletEditable", function () {
    test("a theme-owned outlet is PUBLISHED", function (assert) {
      const query = buildQuery({
        metaByOutlet: { home: { source: LAYOUT_SOURCE.THEME } },
      });
      assert.strictEqual(query.outletState("home"), OUTLET_STATE.PUBLISHED);
      assert.true(query.isOutletEditable("home"));
    });

    test("a non-overridable code outlet is LOCKED and not editable", function (assert) {
      const query = buildQuery({
        metaByOutlet: {
          home: { source: LAYOUT_SOURCE.CODE, overridable: false },
        },
      });
      assert.strictEqual(query.outletState("home"), OUTLET_STATE.LOCKED);
      assert.false(query.isOutletEditable("home"));
    });

    test("an overridable code seed (or no layer at all) is DEFAULT", function (assert) {
      const query = buildQuery({
        metaByOutlet: {
          seeded: { source: LAYOUT_SOURCE.CODE, overridable: true },
        },
      });
      assert.strictEqual(query.outletState("seeded"), OUTLET_STATE.DEFAULT);
      assert.strictEqual(
        query.outletState("nothing"),
        OUTLET_STATE.DEFAULT,
        "no underlying layer is also the default"
      );
      assert.true(query.isOutletEditable("seeded"));
      assert.true(query.isOutletEditable("nothing"));
    });
  });

  module("grid predicates", function () {
    test("isGridContainer is true only for a layout in grid mode", function (assert) {
      const query = buildQuery();
      assert.true(
        query.isGridContainer(
          entry({ block: "layout", stableKey: 1, args: { mode: "grid" } })
        )
      );
      assert.true(
        query.isGridContainer(
          entry({ block: "layout", stableKey: 1, args: { mode: "free-grid" } })
        ),
        "the legacy free-grid alias still counts"
      );
      assert.false(
        query.isGridContainer(
          entry({ block: "layout", stableKey: 1, args: { mode: "flex" } })
        ),
        "a non-grid layout is not a grid container"
      );
      assert.false(
        query.isGridContainer(
          entry({ block: "tile", stableKey: 1, args: { mode: "grid" } })
        ),
        "only the layout block counts"
      );
    });

    test("isGridCellEntry is true when the entry carries a grid placement", function (assert) {
      const query = buildQuery();
      assert.true(
        query.isGridCellEntry(
          entry({ block: "tile", stableKey: 1, containerArgs: { grid: {} } })
        )
      );
      assert.false(
        query.isGridCellEntry(entry({ block: "tile", stableKey: 1 }))
      );
      assert.false(query.isGridCellEntry(null));
    });

    test("isCellInGrid checks the entry's parent is the named grid", function (assert) {
      const cell = entry({
        block: "tile",
        stableKey: 2,
        containerArgs: { grid: {} },
      });
      const grid = entry({
        block: "layout",
        stableKey: 1,
        args: { mode: "grid" },
        children: [cell],
      });
      const query = buildQuery({ layouts: { home: [grid] } });
      assert.true(query.isCellInGrid(cell, "layout:1"));
      assert.false(
        query.isCellInGrid(cell, "layout:99"),
        "a different grid key does not match"
      );
      assert.false(
        query.isCellInGrid(entry({ block: "tile", stableKey: 3 }), "layout:1"),
        "a non-cell entry is never in a grid"
      );
    });
  });

  module("isComposedComposite", function () {
    // isComposedComposite resolves metadata by NAME (via getBlock), so the
    // composite's class must be reachable through `blocksByName`.
    const composites = {
      "layout-query-test-card": CardBlock,
      "layout-query-test-tile": TileBlock,
    };

    test("true for a parts-declaring block with no explicit children", function (assert) {
      const composite = entry({ block: CardBlock, stableKey: 1 });
      const query = buildQuery({
        layouts: { home: [composite] },
        blocksByName: composites,
      });
      assert.true(query.isComposedComposite("layout-query-test-card:1"));
    });

    test("false once the composite is detached (has explicit children)", function (assert) {
      const detached = entry({
        block: CardBlock,
        stableKey: 1,
        children: [entry({ block: TileBlock, stableKey: 2 })],
      });
      const query = buildQuery({
        layouts: { home: [detached] },
        blocksByName: composites,
      });
      assert.false(query.isComposedComposite("layout-query-test-card:1"));
    });

    test("false for a plain block and a missing key", function (assert) {
      const tile = entry({ block: TileBlock, stableKey: 1 });
      const query = buildQuery({
        layouts: { home: [tile] },
        blocksByName: composites,
      });
      assert.false(query.isComposedComposite("layout-query-test-tile:1"));
      assert.false(query.isComposedComposite("missing:9"));
    });
  });

  module("outlet-root identity", function () {
    test("records, reads, and clears outlet-root keys", function (assert) {
      const root = entry({ block: "layout", stableKey: 1 });
      const query = buildQuery({ layouts: { home: [root] } });

      assert.strictEqual(
        query.outletRootKey("home"),
        null,
        "nothing recorded yet"
      );
      assert.false(query.isOutletRoot("layout:1"));

      query.recordOutletRoot("home");
      assert.strictEqual(query.outletRootKey("home"), "layout:1");
      assert.true(query.isOutletRoot("layout:1"));
      assert.false(query.isOutletRoot("tile:9"));
      assert.false(query.isOutletRoot(null));

      query.clearOutletRoots();
      assert.strictEqual(query.outletRootKey("home"), null);
      assert.false(query.isOutletRoot("layout:1"));
    });

    test("recordOutletRoot is a no-op when the outlet has no layout", function (assert) {
      const query = buildQuery({ layouts: {} });
      query.recordOutletRoot("home");
      assert.strictEqual(query.outletRootKey("home"), null);
    });
  });

  module("outletForEntry", function () {
    test("finds the outlet that owns a live entry reference", function (assert) {
      const nested = entry({ block: "tile", stableKey: 2 });
      const container = entry({
        block: "layout",
        stableKey: 1,
        children: [nested],
      });
      const query = buildQuery({
        layouts: { other: [], home: [container] },
      });
      assert.strictEqual(query.outletForEntry(container), "home");
      assert.strictEqual(
        query.outletForEntry(nested),
        "home",
        "walks into children"
      );
      assert.strictEqual(
        query.outletForEntry(entry({ block: "tile", stableKey: 9 })),
        null,
        "an entry present in no layout resolves to null"
      );
    });
  });
});
