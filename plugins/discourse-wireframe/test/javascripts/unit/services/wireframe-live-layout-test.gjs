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
import { engineOf, queryOf } from "../../helpers/wireframe-peers";

const DRAFTS_URL = "/admin/plugins/wireframe/block-layout-drafts.json";

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
  getOwner(editor)
    .lookup("service:wireframe-inspector-args")
    .updateSelectedArg(argName, value);
  await settled();
}

// A successful publish drops the now-redundant draft, so the drafts DELETE must
// be mocked for the success paths or the cleanup would hit an unmocked route.
function stubDraftsDelete() {
  pretender.delete(DRAFTS_URL, () => response({ success: true }));
}

module(
  "Unit | Discourse Wireframe | service:wireframe-live-layout",
  function (hooks) {
    setupTest(hooks);

    hooks.beforeEach(function () {
      this.editor = getOwner(this).lookup("service:wireframe-workspace");
      this.persistence = getOwner(this).lookup("service:wireframe-live-layout");
      this.theme = getOwner(this).lookup("service:wireframe-publish-target");
    });

    hooks.afterEach(function () {
      _resetOutletLayoutsForTesting();
      this.editor.exit();
    });

    async function enterEdited(context) {
      withTestBlockRegistration(() => registerBlock(PersistTile));
      const layout = await registerLayout(getOwner(context));
      const stableKey = layout[0].__stableKey;

      context.editor.wireframeSelection.selectBlock({
        key: `wf:persist-test-tile:${stableKey}`,
        name: "wf:persist-test-tile",
        args: { title: "Original" },
        metadata: { args: { title: { type: "string" } } },
      });
      await editArg(context.editor, "title", "Edited");
    }

    test("publish posts every edited outlet with the version token", async function (assert) {
      await enterEdited(this);
      stubDraftsDelete();

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

    test("publish targets the design, not the theme that currently owns the outlet", async function (assert) {
      await enterEdited(this);
      stubDraftsDelete();
      // The outlet currently resolves to theme 7 (e.g. the theme in use); the
      // design passed as the target (5) must receive the write.
      this.theme.outletOwner = () => ({ themeId: 7, isGit: true });

      pretender.post("/admin/customize/block-layouts.json", (request) => {
        assert.strictEqual(parsePostData(request.requestBody).theme_id, "5");
        assert.step("posted-5");
        return response({ success: true, theme_id: 5, version_token: "v1" });
      });

      const result = await this.persistence.publish(5);
      assert.strictEqual(result.saved[0].themeId, 5);
      assert.verifySteps(["posted-5"]);
    });

    test("publish collapses the draft into the theme layer keyed by the requested theme and clears the edited-outlets bookkeeping", async function (assert) {
      await enterEdited(this);
      stubDraftsDelete();

      assert.true(engineOf(this.editor).isOutletEdited("homepage-blocks"));

      pretender.post("/admin/customize/block-layouts.json", () =>
        response({ success: true, theme_id: 5, version_token: "v1" })
      );

      await this.persistence.publish(5);

      assert.false(
        engineOf(this.editor).isOutletEdited("homepage-blocks"),
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

    test("publish flags a 409 conflict with the live version and keeps the outlet edited", async function (assert) {
      await enterEdited(this);

      pretender.post("/admin/customize/block-layouts.json", () =>
        response(409, {
          errors: ["This layout was changed by someone else."],
          current_version: "server-token",
          published_at: "2026-06-19T12:00:00Z",
        })
      );

      const result = await this.persistence.publish(5);
      assert.strictEqual(result.saved.length, 0);
      assert.strictEqual(result.errors.length, 1);
      assert.true(result.errors[0].conflict, "flags the 409 as a conflict");
      assert.strictEqual(result.errors[0].currentVersion, "server-token");
      assert.strictEqual(result.errors[0].publishedAt, "2026-06-19T12:00:00Z");
      assert.true(
        engineOf(this.editor).isOutletEdited("homepage-blocks"),
        "the edit is preserved on conflict"
      );
    });

    test("publish records non-conflict errors per outlet and continues", async function (assert) {
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
      queryOf(this.editor).readResolvedLayout = () => null;

      pretender.post("/admin/customize/block-layouts.json", () => {
        assert.step("posted");
        return response({ success: true, theme_id: 5, version_token: "v1" });
      });

      const result = await this.persistence.publish(5);
      assert.strictEqual(result.saved.length, 0);
      assert.strictEqual(result.errors.length, 1);
      assert.true(result.errors[0].message.includes("empty/unreadable"));
      assert.true(engineOf(this.editor).isOutletEdited("homepage-blocks"));
      assert.verifySteps([]);
    });

    test("overwriteOutlet re-posts with the server's current version", async function (assert) {
      await enterEdited(this);
      stubDraftsDelete();

      pretender.post("/admin/customize/block-layouts.json", (request) => {
        assert.strictEqual(
          parsePostData(request.requestBody).expected_version_token,
          "server-token",
          "overwrite echoes the server's current version as the expected token"
        );
        assert.step("overwritten");
        return response({ success: true, theme_id: 5, version_token: "v2" });
      });

      const ok = await this.persistence.overwriteOutlet(
        "homepage-blocks",
        5,
        "server-token"
      );
      assert.true(ok);
      assert.false(engineOf(this.editor).isOutletEdited("homepage-blocks"));
      assert.verifySteps(["overwritten"]);
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

    test("createDesign posts the name, and the edited drafts when asked", async function (assert) {
      await enterEdited(this);

      pretender.post(
        "/admin/plugins/wireframe/customization-component.json",
        (request) => {
          const body = parsePostData(request.requestBody);
          assert.strictEqual(body.theme_id, "5");
          assert.strictEqual(body.name, "Spring launch");
          assert.true(request.requestBody.includes("homepage-blocks"));
          assert.step("created");
          return response({ theme_id: 99 });
        }
      );

      const result = await this.persistence.createDesign(5, "Spring launch", {
        withEdits: true,
      });
      assert.strictEqual(result.theme_id, 99);
      assert.verifySteps(["created"]);
    });

    test("createDesign sends no drafts by default", async function (assert) {
      await enterEdited(this);

      pretender.post(
        "/admin/plugins/wireframe/customization-component.json",
        (request) => {
          assert.false(request.requestBody.includes("homepage-blocks"));
          return response({ theme_id: 99 });
        }
      );

      await this.persistence.createDesign(5, "Spring launch");
    });

    test("installDesign puts the chosen design on the theme", async function (assert) {
      pretender.put("/admin/plugins/wireframe/companion.json", (request) => {
        const body = parsePostData(request.requestBody);
        assert.strictEqual(body.theme_id, "5");
        assert.strictEqual(body.design_id, "99");
        assert.step("installed");
        return response({ success: "OK" });
      });

      await this.persistence.installDesign(5, 99);
      assert.verifySteps(["installed"]);
    });
  }
);
