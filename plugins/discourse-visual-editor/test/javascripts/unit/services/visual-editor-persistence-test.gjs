import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import {
  _getRawOutletLayouts,
  _renderBlocks,
  _resetOutletLayoutsForTesting,
  LAYOUT_LAYERS,
} from "discourse/blocks/block-outlet";
import {
  registerBlock,
  withTestBlockRegistration,
} from "discourse/tests/helpers/block-testing";
import pretender, {
  parsePostData,
  response,
} from "discourse/tests/helpers/create-pretender";

@block("ve-persist-test:tile", { args: { title: { type: "string" } } })
class PersistTile extends Component {
  <template>
    <div class="tile">{{@title}}</div>
  </template>
}

async function registerLayout(owner) {
  return _renderBlocks(
    "homepage-blocks",
    [{ block: PersistTile, args: { title: "Original" } }],
    owner
  );
}

async function editArg(editor, argName, value) {
  editor.updateSelectedArg(argName, value);
  return editor._flushPendingArgs();
}

module(
  "Unit | Discourse Visual Editor | service:visual-editor-persistence",
  function (hooks) {
    setupTest(hooks);

    hooks.beforeEach(function () {
      this.editor = getOwner(this).lookup("service:visual-editor");
      this.persistence = getOwner(this).lookup(
        "service:visual-editor-persistence"
      );
    });

    hooks.afterEach(function () {
      _resetOutletLayoutsForTesting();
      this.editor.exit();
    });

    test("saveAll posts every drafted outlet to the server", async function (assert) {
      withTestBlockRegistration(() => registerBlock(PersistTile));
      const layout = await registerLayout(getOwner(this));
      const stableKey = layout[0].__stableKey;

      this.editor.selectBlock({
        key: `ve-persist-test:tile:${stableKey}`,
        name: "ve-persist-test:tile",
        args: { title: "Original" },
        metadata: { args: { title: { type: "string" } } },
      });
      await editArg(this.editor, "title", "Edited");

      pretender.post("/admin/customize/block-layouts.json", (request) => {
        const body = parsePostData(request.requestBody);
        assert.strictEqual(body.theme_id, "5");
        assert.strictEqual(body.outlet_name, "homepage-blocks");
        const payload = JSON.parse(body.layout_json);
        assert.strictEqual(payload.schema_version, 1);
        assert.strictEqual(payload.layout[0].block, "ve-persist-test:tile");
        assert.strictEqual(payload.layout[0].args.title, "Edited");
        assert.step("posted");
        return response({
          success: true,
          target_theme_id: 5,
          target_theme_name: "Light",
          redirected: false,
          child_created: false,
        });
      });

      const result = await this.persistence.saveAll(5);
      assert.strictEqual(result.saved.length, 1);
      assert.strictEqual(result.errors.length, 0);
      assert.verifySteps(["posted"]);
    });

    test("saveAll publishes the saved layout to the theme layer and clears the edited-outlets bookkeeping", async function (assert) {
      withTestBlockRegistration(() => registerBlock(PersistTile));
      const layout = await registerLayout(getOwner(this));
      const stableKey = layout[0].__stableKey;

      this.editor.selectBlock({
        key: `ve-persist-test:tile:${stableKey}`,
        name: "ve-persist-test:tile",
        args: { title: "Original" },
        metadata: { args: { title: { type: "string" } } },
      });
      await editArg(this.editor, "title", "Edited");

      assert.true(
        this.editor._editedOutlets.has("homepage-blocks"),
        "outlet recorded as edited after first mutation"
      );

      pretender.post("/admin/customize/block-layouts.json", () => {
        return response({
          success: true,
          target_theme_id: 7,
          target_theme_name: "Saved",
          redirected: false,
          child_created: false,
        });
      });

      await this.persistence.saveAll(5);

      assert.false(
        this.editor._editedOutlets.has("homepage-blocks"),
        "edited-outlet bookkeeping cleared after save"
      );

      const record = _getRawOutletLayouts().get("homepage-blocks");
      assert.strictEqual(
        record[LAYOUT_LAYERS.THEME].length,
        1,
        "theme layer published with the saved layout"
      );
      assert.strictEqual(
        record[LAYOUT_LAYERS.THEME][0].themeId,
        7,
        "theme layer keyed by the server-returned target_theme_id"
      );
    });

    test("saveAll records errors per outlet and continues", async function (assert) {
      withTestBlockRegistration(() => registerBlock(PersistTile));
      const layout = await registerLayout(getOwner(this));
      const stableKey = layout[0].__stableKey;

      this.editor.selectBlock({
        key: `ve-persist-test:tile:${stableKey}`,
        name: "ve-persist-test:tile",
        args: { title: "Original" },
        metadata: { args: { title: { type: "string" } } },
      });
      await editArg(this.editor, "title", "Edited");

      pretender.post("/admin/customize/block-layouts.json", () => {
        return response(422, { errors: ["Layout exceeds max depth"] });
      });

      const result = await this.persistence.saveAll(5);
      assert.strictEqual(result.saved.length, 0);
      assert.strictEqual(result.errors.length, 1);
      assert.strictEqual(result.errors[0].outlet, "homepage-blocks");
      assert.true(result.errors[0].message.includes("max depth"));
    });

    test("saveAll is a no-op when no outlet has been edited", async function (assert) {
      const result = await this.persistence.saveAll(5);
      assert.strictEqual(result.saved.length, 0);
      assert.strictEqual(result.errors.length, 0);
    });
  }
);
