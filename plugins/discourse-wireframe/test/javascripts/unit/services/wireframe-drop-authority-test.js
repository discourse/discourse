import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";

// Looks up the drop-authority service and wires its two dependencies for the
// scenario: drives the real drag-session service to set the in-flight source
// (when `sourceKey` is given), and stubs the layout-query service's entry/
// metadata lookups. `entries` maps a key to an object carrying its `meta`
// (outlet restrictions); `metaByName` maps a block name to its metadata.
function buildAuthority(
  owner,
  { sourceKey = null, sourceOutlet = null, entries = {}, metaByName = {} } = {}
) {
  if (sourceKey) {
    owner
      .lookup("service:wireframe-drag-session")
      .beginBlock({ blockKey: sourceKey, outletName: sourceOutlet });
  }
  const layoutQuery = owner.lookup("service:wireframe-layout-query");
  sinon
    .stub(layoutQuery, "findEntryByKey")
    .callsFake((key) => entries[key] ?? null);
  sinon
    .stub(layoutQuery, "metadataFor")
    .callsFake((entry) => entry?.meta ?? null);
  sinon
    .stub(layoutQuery, "metadataForName")
    .callsFake((name) => metaByName[name] ?? null);
  return owner.lookup("service:wireframe-drop-authority");
}

module(
  "Unit | Discourse Wireframe | service:wireframe-drop-authority",
  function (hooks) {
    setupTest(hooks);

    hooks.afterEach(function () {
      sinon.restore();
      getOwner(this).lookup("service:wireframe-drag-session").clear();
    });

    module("canDropAt", function () {
      test("permits when there is no drag source (idle)", function (assert) {
        const auth = buildAuthority(getOwner(this));
        assert.true(auth.canDropAt({ targetOutletName: "homepage-blocks" }));
      });

      test("permits a same-outlet move", function (assert) {
        const auth = buildAuthority(getOwner(this), {
          sourceKey: "para:1",
          sourceOutlet: "homepage-blocks",
        });
        assert.true(auth.canDropAt({ targetOutletName: "homepage-blocks" }));
      });

      test("refuses when the source entry can't be found", function (assert) {
        const auth = buildAuthority(getOwner(this), {
          sourceKey: "para:1",
          sourceOutlet: "a",
          entries: {},
        });
        assert.false(auth.canDropAt({ targetOutletName: "b" }));
      });

      test("honors allowedOutlets for a cross-outlet move", function (assert) {
        const auth = buildAuthority(getOwner(this), {
          sourceKey: "para:1",
          sourceOutlet: "a",
          entries: { "para:1": { meta: { allowedOutlets: ["b"] } } },
        });
        assert.true(
          auth.canDropAt({ targetOutletName: "b" }),
          "allowed outlet"
        );
        assert.false(
          auth.canDropAt({ targetOutletName: "c" }),
          "outlet not in the allow-list"
        );
      });

      test("is permissive when the source block has no metadata", function (assert) {
        const auth = buildAuthority(getOwner(this), {
          sourceKey: "para:1",
          sourceOutlet: "a",
          entries: { "para:1": { meta: null } },
        });
        assert.true(auth.canDropAt({ targetOutletName: "b" }));
      });
    });

    module("canInsertBlockAt", function () {
      test("refuses when blockName or targetOutletName is missing", function (assert) {
        const auth = buildAuthority(getOwner(this));
        assert.false(
          auth.canInsertBlockAt({ blockName: "", targetOutletName: "a" })
        );
        assert.false(
          auth.canInsertBlockAt({ blockName: "x", targetOutletName: "" })
        );
      });

      test("is permissive for an unknown block (no metadata)", function (assert) {
        const auth = buildAuthority(getOwner(this), { metaByName: {} });
        assert.true(
          auth.canInsertBlockAt({ blockName: "x", targetOutletName: "a" })
        );
      });

      test("honors allowedOutlets", function (assert) {
        const auth = buildAuthority(getOwner(this), {
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
        const auth = buildAuthority(getOwner(this), {
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
  }
);
