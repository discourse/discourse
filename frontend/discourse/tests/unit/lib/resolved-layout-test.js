import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import {
  _getResolvedLayout,
  _getResolvedLayoutMeta,
  _getResolvedLayouts,
  _renderBlocks,
  _resetOutletLayoutsForTesting,
  _setLayoutLayer,
  LAYOUT_LAYERS,
  LAYOUT_SOURCE,
} from "discourse/blocks/block-outlet";
import {
  registerBlock,
  withTestBlockRegistration,
} from "discourse/tests/helpers/block-testing";

// These accessors are the production-safe read path for resolved outlet
// layouts. Their whole point is that — unlike `_getOutletLayouts` /
// `_getRawOutletLayouts` — they have NO `if (!DEBUG)` gate, so they return real
// data in every build. The test build runs with DEBUG === true, but because the
// accessors under test have no gate at all, these tests exercise the exact code
// path a production (`!DEBUG`) build runs, which is what guards against the
// read-returns-null / save-wipes-the-layout regression.
module("Unit | lib | resolved-layout accessors", function (hooks) {
  setupTest(hooks);

  hooks.afterEach(function () {
    _resetOutletLayoutsForTesting();
  });

  test("_getResolvedLayout returns the resolved layout array for a registered outlet", function (assert) {
    @block("resolved-layout-tile-a")
    class Tile extends Component {}

    withTestBlockRegistration(() => registerBlock(Tile));

    _renderBlocks("homepage-blocks", [{ block: Tile }], getOwner(this));

    const layout = _getResolvedLayout("homepage-blocks");
    assert.true(Array.isArray(layout), "returns an array");
    assert.true(
      layout.length > 0,
      "the array is non-empty — not the production null/empty-wipe bug"
    );
    assert.strictEqual(
      layout[0].block,
      Tile,
      "the entry references the registered block"
    );
  });

  test("_getResolvedLayout returns null for an unregistered outlet", function (assert) {
    assert.strictEqual(_getResolvedLayout("never-registered-outlet"), null);
  });

  test("_getResolvedLayouts exposes the same resolved entry, keyed by outlet name", function (assert) {
    @block("resolved-layout-tile-b")
    class Tile extends Component {}

    withTestBlockRegistration(() => registerBlock(Tile));

    _renderBlocks("homepage-blocks", [{ block: Tile }], getOwner(this));

    const map = _getResolvedLayouts();
    assert.true(map.size > 0, "the map is populated (no DEBUG gate)");

    const entry = map.get("homepage-blocks");
    assert.strictEqual(
      entry.layout,
      _getResolvedLayout("homepage-blocks"),
      "the map entry's layout is the same resolved array as _getResolvedLayout"
    );
    assert.strictEqual(entry.layout[0].block, Tile);
  });

  test("_getResolvedLayoutMeta returns the winning layer's provenance", function (assert) {
    @block("resolved-layout-tile-meta")
    class Tile extends Component {}

    withTestBlockRegistration(() => registerBlock(Tile));

    // An overridable code seed is the in-code default.
    _renderBlocks("homepage-blocks", [{ block: Tile }], getOwner(this));
    let meta = _getResolvedLayoutMeta("homepage-blocks");
    assert.strictEqual(meta.source, LAYOUT_SOURCE.CODE);
    assert.true(meta.overridable, "a code seed is overridable");

    assert.strictEqual(
      _getResolvedLayoutMeta("never-registered-outlet"),
      null,
      "returns null when no layer is set"
    );
  });

  test("_getResolvedLayoutMeta with ignoreSessionDraft resolves the underlying source", function (assert) {
    @block("resolved-layout-tile-base")
    class Tile extends Component {}

    withTestBlockRegistration(() => registerBlock(Tile));

    _setLayoutLayer(
      "homepage-blocks",
      LAYOUT_LAYERS.THEME,
      [{ block: Tile }],
      getOwner(this),
      { themeId: 7, themeStackIndex: 0 }
    );
    _setLayoutLayer(
      "homepage-blocks",
      LAYOUT_LAYERS.SESSION_DRAFT,
      [{ block: Tile }],
      getOwner(this),
      { permissive: true }
    );

    // The draft wins normal resolution...
    assert.strictEqual(
      _getResolvedLayoutMeta("homepage-blocks").source,
      LAYOUT_SOURCE.SESSION_DRAFT
    );
    // ...but ignoreSessionDraft reveals the theme underneath, with its id + rank.
    const base = _getResolvedLayoutMeta("homepage-blocks", {
      ignoreSessionDraft: true,
    });
    assert.strictEqual(base.source, LAYOUT_SOURCE.THEME);
    assert.strictEqual(base.sourceId, 7);
    assert.strictEqual(base.themeStackIndex, 0);
  });

  test("the accessors have no DEBUG gate (regression guard against a re-added early return)", function (assert) {
    @block("resolved-layout-tile-c")
    class Tile extends Component {}

    withTestBlockRegistration(() => registerBlock(Tile));

    _renderBlocks("homepage-blocks", [{ block: Tile }], getOwner(this));

    // If anyone re-adds an `if (!DEBUG) { return ... }` early return to these
    // accessors, both assertions fail immediately and flag the data-loss
    // regression they exist to prevent.
    assert.notStrictEqual(
      _getResolvedLayout("homepage-blocks"),
      null,
      "_getResolvedLayout returns data, not null"
    );
    assert.true(
      _getResolvedLayouts().size > 0,
      "_getResolvedLayouts returns a populated map"
    );
  });
});
