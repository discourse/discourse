import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import {
  _getRawOutletLayouts,
  _renderBlocks,
  _resetOutletLayoutsForTesting,
  _setLayoutLayer,
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

@block("wf:persist-test-tile", { args: { title: { type: "string" } } })
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
  await settled();
}

module(
  "Unit | Discourse Wireframe | service:wireframe-persistence",
  function (hooks) {
    setupTest(hooks);

    hooks.beforeEach(function () {
      this.editor = getOwner(this).lookup("service:wireframe");
      this.persistence = getOwner(this).lookup("service:wireframe-persistence");
    });

    hooks.afterEach(function () {
      _resetOutletLayoutsForTesting();
      this.editor.exit();
    });

    async function enterEdited(context) {
      withTestBlockRegistration(() => registerBlock(PersistTile));
      const layout = await registerLayout(getOwner(context));
      const stableKey = layout[0].__stableKey;

      context.editor.selectBlock({
        key: `wf:persist-test-tile:${stableKey}`,
        name: "wf:persist-test-tile",
        args: { title: "Original" },
        metadata: { args: { title: { type: "string" } } },
      });
      await editArg(context.editor, "title", "Edited");
    }

    test("publish posts every edited outlet with the version token", async function (assert) {
      await enterEdited(this);

      pretender.post("/admin/customize/block-layouts.json", (request) => {
        const body = parsePostData(request.requestBody);
        assert.strictEqual(body.theme_id, "5");
        assert.strictEqual(body.outlet_name, "homepage-blocks");
        // No live field has been seen, so the first publish sends an empty token.
        assert.strictEqual(body.expected_version_token, "");
        const payload = JSON.parse(body.layout_json);
        assert.true(payload.layout.length > 0);
        assert.strictEqual(payload.layout[0].args.title, "Edited");
        assert.step("posted");
        return response({ success: true, theme_id: 5, version_token: "v1" });
      });

      const result = await this.persistence.publish(5);
      assert.strictEqual(result.saved.length, 1);
      assert.strictEqual(result.errors.length, 0);
      assert.verifySteps(["posted"]);
    });

    test("publish collapses the draft into the theme layer keyed by the requested theme and clears the edited-outlets bookkeeping", async function (assert) {
      await enterEdited(this);

      assert.true(this.editor.editedOutlets.has("homepage-blocks"));

      pretender.post("/admin/customize/block-layouts.json", () =>
        response({ success: true, theme_id: 5, version_token: "v1" })
      );

      await this.persistence.publish(5);

      assert.false(
        this.editor.editedOutlets.has("homepage-blocks"),
        "edited-outlet bookkeeping cleared after publish"
      );

      const record = _getRawOutletLayouts().get("homepage-blocks");
      assert.strictEqual(record[LAYOUT_LAYERS.THEME].length, 1);
      assert.strictEqual(
        record[LAYOUT_LAYERS.THEME][0].themeId,
        5,
        "theme layer keyed by the requested theme id, not a server redirect"
      );
    });

    test("publish keeps the outlet edited and flags a conflict on 409", async function (assert) {
      await enterEdited(this);

      pretender.post("/admin/customize/block-layouts.json", () =>
        response(409, { errors: ["This layout was changed by someone else."] })
      );

      const result = await this.persistence.publish(5);
      assert.strictEqual(result.saved.length, 0);
      assert.strictEqual(result.errors.length, 1);
      assert.true(result.errors[0].conflict, "flags the 409 as a conflict");
      assert.true(
        this.editor.editedOutlets.has("homepage-blocks"),
        "the edit is preserved on conflict"
      );
    });

    test("publish records errors per outlet and continues", async function (assert) {
      await enterEdited(this);

      pretender.post("/admin/customize/block-layouts.json", () =>
        response(422, { errors: ["Layout exceeds max depth"] })
      );

      const result = await this.persistence.publish(5);
      assert.strictEqual(result.saved.length, 0);
      assert.strictEqual(result.errors.length, 1);
      assert.false(result.errors[0].conflict);
      assert.true(result.errors[0].message.includes("max depth"));
    });

    test("publish is a no-op when no outlet has been edited", async function (assert) {
      const result = await this.persistence.publish(5);
      assert.strictEqual(result.saved.length, 0);
      assert.strictEqual(result.errors.length, 0);
    });

    test("publish refuses to POST and keeps the draft when the resolved read fails", async function (assert) {
      await enterEdited(this);
      this.editor.readResolvedLayout = () => null;

      pretender.post("/admin/customize/block-layouts.json", () => {
        assert.step("posted");
        return response({ success: true, theme_id: 5, version_token: "v1" });
      });

      const result = await this.persistence.publish(5);
      assert.strictEqual(result.saved.length, 0);
      assert.strictEqual(result.errors.length, 1);
      assert.true(result.errors[0].message.includes("empty/unreadable"));
      assert.true(this.editor.editedOutlets.has("homepage-blocks"));
      assert.verifySteps([]);
    });

    test("saveDraft posts the drafts endpoint and leaves the theme layer untouched", async function (assert) {
      await enterEdited(this);

      pretender.post(
        "/admin/plugins/wireframe/block-layout-drafts.json",
        (request) => {
          const body = parsePostData(request.requestBody);
          assert.strictEqual(body.theme_id, "5");
          assert.strictEqual(body.outlet_name, "homepage-blocks");
          const payload = JSON.parse(body.layout_json);
          assert.strictEqual(payload.layout[0].args.title, "Edited");
          assert.step("drafted");
          return response({ success: true });
        }
      );

      const result = await this.persistence.saveDraft(5);
      assert.strictEqual(result.saved.length, 1);
      assert.verifySteps(["drafted"]);

      const record = _getRawOutletLayouts().get("homepage-blocks");
      assert.strictEqual(
        record[LAYOUT_LAYERS.THEME].length,
        0,
        "a draft does not collapse into the theme layer"
      );
      assert.true(
        this.editor.editedOutlets.has("homepage-blocks"),
        "the outlet stays edited after a draft save"
      );
    });

    test("resetToDefault deletes the field and clears the theme layer", async function (assert) {
      withTestBlockRegistration(() => registerBlock(PersistTile));
      _setLayoutLayer(
        "homepage-blocks",
        LAYOUT_LAYERS.THEME,
        [{ block: PersistTile, args: { title: "Published" } }],
        getOwner(this),
        { themeId: 5 }
      );
      await settled();

      pretender.delete("/admin/customize/block-layouts.json", () => {
        assert.step("deleted");
        return response({ success: true, theme_id: 5 });
      });

      await this.persistence.resetToDefault(5, "homepage-blocks");
      assert.verifySteps(["deleted"]);

      const record = _getRawOutletLayouts().get("homepage-blocks");
      const themeLayerCleared =
        record == null || record[LAYOUT_LAYERS.THEME].length === 0;
      assert.true(themeLayerCleared, "the theme layer is cleared locally");
    });

    test("discardDraft issues a DELETE to the drafts endpoint", async function (assert) {
      pretender.delete(
        "/admin/plugins/wireframe/block-layout-drafts.json",
        () => {
          assert.step("discarded");
          return response({ success: true });
        }
      );

      await this.persistence.discardDraft(5, "homepage-blocks");
      assert.verifySteps(["discarded"]);
    });
  }
);
