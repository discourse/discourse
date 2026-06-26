import { module, test } from "qunit";
import DropAuthority from "discourse/plugins/discourse-wireframe/discourse/lib/drop-authority";

// A minimal stand-in for the drag-session leaf — DropAuthority only reads
// `sourceKey` / `sourceOutlet`.
function session(sourceKey = null, sourceOutlet = null) {
  return { sourceKey, sourceOutlet };
}

// Builds a DropAuthority with controllable lookups. Entries map a key to an
// object carrying its `meta` (outlet restrictions); `metaByName` maps a block
// name to its metadata.
function buildAuthority({
  sess = session(),
  entries = {},
  metaByName = {},
} = {}) {
  return new DropAuthority({
    session: sess,
    findEntryByKey: (key) => entries[key] ?? null,
    metadataFor: (entry) => entry?.meta ?? null,
    metadataForName: (name) => metaByName[name] ?? null,
  });
}

module("Unit | Discourse Wireframe | lib:drop-authority", function () {
  module("canDropAt", function () {
    test("permits when there is no drag source (idle)", function (assert) {
      const auth = buildAuthority({ sess: session(null) });
      assert.true(auth.canDropAt({ targetOutletName: "homepage-blocks" }));
    });

    test("permits a same-outlet move", function (assert) {
      const auth = buildAuthority({
        sess: session("para:1", "homepage-blocks"),
      });
      assert.true(auth.canDropAt({ targetOutletName: "homepage-blocks" }));
    });

    test("refuses when the source entry can't be found", function (assert) {
      const auth = buildAuthority({
        sess: session("para:1", "a"),
        entries: {},
      });
      assert.false(auth.canDropAt({ targetOutletName: "b" }));
    });

    test("honors allowedOutlets for a cross-outlet move", function (assert) {
      const auth = buildAuthority({
        sess: session("para:1", "a"),
        entries: { "para:1": { meta: { allowedOutlets: ["b"] } } },
      });
      assert.true(auth.canDropAt({ targetOutletName: "b" }), "allowed outlet");
      assert.false(
        auth.canDropAt({ targetOutletName: "c" }),
        "outlet not in the allow-list"
      );
    });

    test("is permissive when the source block has no metadata", function (assert) {
      const auth = buildAuthority({
        sess: session("para:1", "a"),
        entries: { "para:1": { meta: null } },
      });
      assert.true(auth.canDropAt({ targetOutletName: "b" }));
    });
  });

  module("canInsertBlockAt", function () {
    test("refuses when blockName or targetOutletName is missing", function (assert) {
      const auth = buildAuthority();
      assert.false(
        auth.canInsertBlockAt({ blockName: "", targetOutletName: "a" })
      );
      assert.false(
        auth.canInsertBlockAt({ blockName: "x", targetOutletName: "" })
      );
    });

    test("is permissive for an unknown block (no metadata)", function (assert) {
      const auth = buildAuthority({ metaByName: {} });
      assert.true(
        auth.canInsertBlockAt({ blockName: "x", targetOutletName: "a" })
      );
    });

    test("honors allowedOutlets", function (assert) {
      const auth = buildAuthority({
        metaByName: { hero: { allowedOutlets: ["a"] } },
      });
      assert.true(
        auth.canInsertBlockAt({ blockName: "hero", targetOutletName: "a" })
      );
      assert.false(
        auth.canInsertBlockAt({ blockName: "hero", targetOutletName: "b" })
      );
    });

    test("honors deniedOutlets", function (assert) {
      const auth = buildAuthority({
        metaByName: { hero: { deniedOutlets: ["a"] } },
      });
      assert.false(
        auth.canInsertBlockAt({ blockName: "hero", targetOutletName: "a" })
      );
      assert.true(
        auth.canInsertBlockAt({ blockName: "hero", targetOutletName: "b" })
      );
    });
  });
});
