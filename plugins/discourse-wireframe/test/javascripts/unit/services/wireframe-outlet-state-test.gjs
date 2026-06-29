import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import {
  _registerMountedOutlet,
  _renderBlocks,
  _resetOutletLayoutsForTesting,
  _setLayoutLayer,
  _unregisterMountedOutlet,
  LAYOUT_LAYERS,
} from "discourse/blocks/block-outlet";
import PreloadStore from "discourse/lib/preload-store";
import {
  registerBlock,
  withTestBlockRegistration,
} from "discourse/tests/helpers/block-testing";
import { OUTLET_STATE } from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-layout-query";
import { setupBlockLayoutDraftsStub } from "../../helpers/stub-block-layout-drafts";

@block("wf:state-test-tile", { args: { title: { type: "string" } } })
class StateTile extends Component {
  <template>
    <div class="tile">{{@title}}</div>
  </template>
}

module(
  "Unit | Discourse Wireframe | service:wireframe outlet state",
  function (hooks) {
    setupTest(hooks);
    setupBlockLayoutDraftsStub(hooks);

    hooks.beforeEach(function () {
      this.editor = getOwner(this).lookup("service:wireframe");
      this.theme = getOwner(this).lookup("service:wireframe-theme");
      withTestBlockRegistration(() => registerBlock(StateTile));
    });

    hooks.afterEach(function () {
      _resetOutletLayoutsForTesting();
      this.editor.exit();
    });

    function tile(title) {
      return [{ block: StateTile, args: { title } }];
    }

    test("an overridable code seed resolves to DEFAULT", async function (assert) {
      await _renderBlocks("homepage-blocks", tile("Seed"), getOwner(this));
      await settled();
      assert.strictEqual(
        this.editor.wireframeLayoutQuery.outletState("homepage-blocks"),
        OUTLET_STATE.DEFAULT
      );
      assert.true(
        this.editor.wireframeLayoutQuery.isOutletEditable("homepage-blocks")
      );
    });

    test("a non-overridable code layout resolves to LOCKED", async function (assert) {
      await _renderBlocks("homepage-blocks", tile("Locked"), getOwner(this), {
        overridable: false,
      });
      await settled();
      assert.strictEqual(
        this.editor.wireframeLayoutQuery.outletState("homepage-blocks"),
        OUTLET_STATE.LOCKED
      );
      assert.false(
        this.editor.wireframeLayoutQuery.isOutletEditable("homepage-blocks")
      );
    });

    test("a theme field resolves to PUBLISHED with the owning theme", async function (assert) {
      PreloadStore.store("themeBlockLayoutMeta", {
        7: { name: "Acme", is_git: true, stack_index: 0 },
      });
      _setLayoutLayer(
        "homepage-blocks",
        LAYOUT_LAYERS.THEME,
        tile("Published"),
        getOwner(this),
        { themeId: 7, themeStackIndex: 0 }
      );
      await settled();

      assert.strictEqual(
        this.editor.wireframeLayoutQuery.outletState("homepage-blocks"),
        OUTLET_STATE.PUBLISHED
      );
      const owner = this.theme.outletOwner("homepage-blocks");
      assert.strictEqual(owner.themeId, 7);
      assert.strictEqual(owner.themeName, "Acme");
      assert.true(owner.isGit, "git status comes from the metadata preload");
    });

    test("the state ignores an in-session draft layered on top", async function (assert) {
      _setLayoutLayer(
        "homepage-blocks",
        LAYOUT_LAYERS.THEME,
        tile("Published"),
        getOwner(this),
        { themeId: 7, themeStackIndex: 0 }
      );
      _setLayoutLayer(
        "homepage-blocks",
        LAYOUT_LAYERS.SESSION_DRAFT,
        tile("Editing"),
        getOwner(this),
        { permissive: true }
      );
      await settled();

      // The draft wins live resolution, but the state reflects the published
      // source underneath it.
      assert.strictEqual(
        this.editor.wireframeLayoutQuery.outletState("homepage-blocks"),
        OUTLET_STATE.PUBLISHED
      );
    });

    test("isOutletEditing flips on the first edit and clears on discard", async function (assert) {
      const layout = await _renderBlocks(
        "homepage-blocks",
        tile("Original"),
        getOwner(this)
      );
      const stableKey = layout[0].__stableKey;
      this.editor.enter({ themeId: 5 });
      await settled();

      assert.false(this.editor.isOutletEditing("homepage-blocks"));

      this.editor.selectBlock({
        key: `wf:state-test-tile:${stableKey}`,
        name: "wf:state-test-tile",
        args: { title: "Original" },
        metadata: { args: { title: { type: "string" } } },
      });
      getOwner(this)
        .lookup("service:wireframe-arg-edit")
        .updateSelectedArg("title", "Edited");
      await settled();

      assert.true(this.editor.isOutletEditing("homepage-blocks"));
    });

    test("defaultThemeId is the current theme (min stack_index), including a negative-id parent", function (assert) {
      // The parent (stack_index 0) is the theme the page renders against — even
      // when it's a seeded theme with a negative id (Foundation = -1). It must
      // NOT be the lowest positive id (a middle component).
      PreloadStore.store("themeBlockLayoutMeta", {
        "-1": { name: "Foundation", is_git: false, stack_index: 0 },
        2: { name: "Discourse Gifs", is_git: false, stack_index: 1 },
        5: { name: "Block Layout", is_git: false, stack_index: 2 },
      });

      assert.strictEqual(this.theme.defaultThemeId, -1);
    });

    test("an outlet mounted on the page is editable even with no layout", function (assert) {
      // Nothing rendered + nothing reset means no layout for this outlet.
      assert.false(
        this.editor.editableOutlets.includes("homepage-blocks"),
        "not editable when it has neither a layout nor a mounted boundary"
      );

      // Simulate a <BlockOutlet> mounting (the blocks service's registry) with
      // no layout — the post-reset "start from scratch" case.
      _registerMountedOutlet("homepage-blocks");
      try {
        assert.true(
          this.editor.editableOutlets.includes("homepage-blocks"),
          "a mounted, layout-less outlet is editable so it can be rebuilt"
        );
      } finally {
        _unregisterMountedOutlet("homepage-blocks");
      }
    });

    test("an unowned outlet targets the active theme, not a default component", async function (assert) {
      // A default (overridable code seed) outlet — nothing owns it yet.
      await _renderBlocks("homepage-blocks", tile("Seed"), getOwner(this));
      await settled();
      assert.strictEqual(
        this.editor.wireframeLayoutQuery.outletState("homepage-blocks"),
        OUTLET_STATE.DEFAULT
      );

      // The session was entered against theme 7, so that's the save target —
      // not a computed default theme.
      getOwner(this).lookup("service:wireframe-theme").setActiveTheme(7);
      assert.strictEqual(
        this.theme.outletOwner("homepage-blocks").themeId,
        7,
        "the owner of an unowned outlet is the active (entered) theme"
      );
    });
  }
);
