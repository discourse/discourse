import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import {
  _renderBlocks,
  _resetOutletLayoutsForTesting,
  _setLayoutLayer,
  LAYOUT_LAYERS,
} from "discourse/blocks/block-outlet";
import PreloadStore from "discourse/lib/preload-store";
import {
  registerBlock,
  withTestBlockRegistration,
} from "discourse/tests/helpers/block-testing";
import { OUTLET_STATE } from "discourse/plugins/discourse-wireframe/discourse/services/wireframe";
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
        this.editor.outletState("homepage-blocks"),
        OUTLET_STATE.DEFAULT
      );
      assert.true(this.editor.isOutletEditable("homepage-blocks"));
    });

    test("a non-overridable code layout resolves to LOCKED", async function (assert) {
      await _renderBlocks("homepage-blocks", tile("Locked"), getOwner(this), {
        overridable: false,
      });
      await settled();
      assert.strictEqual(
        this.editor.outletState("homepage-blocks"),
        OUTLET_STATE.LOCKED
      );
      assert.false(this.editor.isOutletEditable("homepage-blocks"));
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
        this.editor.outletState("homepage-blocks"),
        OUTLET_STATE.PUBLISHED
      );
      const owner = this.editor.outletOwner("homepage-blocks");
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
        this.editor.outletState("homepage-blocks"),
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
      this.editor.updateSelectedArg("title", "Edited");
      await settled();

      assert.true(this.editor.isOutletEditing("homepage-blocks"));
    });
  }
);
