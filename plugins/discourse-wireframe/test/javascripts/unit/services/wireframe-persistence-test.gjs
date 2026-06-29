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
    .lookup("service:wireframe-arg-edit")
    .updateSelectedArg(argName, value);
  await settled();
}

// A successful publish drops the now-redundant draft, so the drafts DELETE must
// be mocked for the success paths or the cleanup would hit an unmocked route.
function stubDraftsDelete() {
  pretender.delete(DRAFTS_URL, () => response({ success: true }));
}

module(
  "Unit | Discourse Wireframe | service:wireframe-persistence",
  function (hooks) {
    setupTest(hooks);

    hooks.beforeEach(function () {
      this.editor = getOwner(this).lookup("service:wireframe");
      this.persistence = getOwner(this).lookup("service:wireframe-persistence");
      this.theme = getOwner(this).lookup("service:wireframe-theme");
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

    test("publish targets each outlet's resolved owner, not the fallback", async function (assert) {
      await enterEdited(this);
      stubDraftsDelete();
      // The outlet resolves to theme 7 as its owner; the fallback (5) must not win.
      this.theme.outletOwner = () => ({ themeId: 7, isGit: false });

      pretender.post("/admin/customize/block-layouts.json", (request) => {
        assert.strictEqual(parsePostData(request.requestBody).theme_id, "7");
        assert.step("posted-7");
        return response({ success: true, theme_id: 7, version_token: "v1" });
      });

      const result = await this.persistence.publish(5);
      assert.strictEqual(result.saved[0].themeId, 7);
      assert.verifySteps(["posted-7"]);
    });

    test("publish skips a Git-owned outlet and preserves its edit", async function (assert) {
      await enterEdited(this);
      this.theme.outletOwner = () => ({ themeId: 9, isGit: true });

      pretender.post("/admin/customize/block-layouts.json", () => {
        assert.step("posted");
        return response({ success: true, theme_id: 9, version_token: "v1" });
      });

      const result = await this.persistence.publish(5);
      assert.strictEqual(result.saved.length, 0);
      assert.strictEqual(result.skipped.length, 1);
      assert.strictEqual(result.skipped[0].reason, "git");
      assert.true(this.editor.isOutletEdited("homepage-blocks"));
      assert.verifySteps([]);
    });

    test("publish collapses the draft into the theme layer keyed by the requested theme and clears the edited-outlets bookkeeping", async function (assert) {
      await enterEdited(this);
      stubDraftsDelete();

      assert.true(this.editor.isOutletEdited("homepage-blocks"));

      pretender.post("/admin/customize/block-layouts.json", () =>
        response({ success: true, theme_id: 5, version_token: "v1" })
      );

      await this.persistence.publish(5);

      assert.false(
        this.editor.isOutletEdited("homepage-blocks"),
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
        this.editor.isOutletEdited("homepage-blocks"),
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
      assert.strictEqual(result.skipped.length, 0);
    });

    test("publish refuses to POST and keeps the draft when the resolved read fails", async function (assert) {
      await enterEdited(this);
      this.editor.layoutQuery.readResolvedLayout = () => null;

      pretender.post("/admin/customize/block-layouts.json", () => {
        assert.step("posted");
        return response({ success: true, theme_id: 5, version_token: "v1" });
      });

      const result = await this.persistence.publish(5);
      assert.strictEqual(result.saved.length, 0);
      assert.strictEqual(result.errors.length, 1);
      assert.true(result.errors[0].message.includes("empty/unreadable"));
      assert.true(this.editor.isOutletEdited("homepage-blocks"));
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
      assert.false(this.editor.isOutletEdited("homepage-blocks"));
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

    test("exportOutlet posts the draft and downloads the server content verbatim", async function (assert) {
      await enterEdited(this);
      let downloaded;
      this.persistence._triggerDownload = (filename, content) => {
        downloaded = { filename, content };
      };

      pretender.post(
        "/admin/customize/block-layouts/export.json",
        (request) => {
          const body = parsePostData(request.requestBody);
          assert.strictEqual(body.outlet_name, "homepage-blocks");
          // useDraft sends the serialized current layout.
          assert.strictEqual(
            JSON.parse(body.layout_json).layout[0].args.title,
            "Edited"
          );
          assert.step("exported");
          return response({
            filename: "block_layouts/homepage-blocks.json",
            content: '{\n  "pretty": true\n}',
          });
        }
      );

      await this.persistence.exportOutlet(5, "homepage-blocks", {
        useDraft: true,
      });
      assert.verifySteps(["exported"]);
      assert.strictEqual(
        downloaded.filename,
        "block_layouts/homepage-blocks.json"
      );
      // Content is passed through untouched — not re-stringified.
      assert.strictEqual(downloaded.content, '{\n  "pretty": true\n}');
    });

    test("duplicateTheme posts every edited outlet's draft and returns the new theme id", async function (assert) {
      await enterEdited(this);

      pretender.post(
        "/admin/customize/block-layouts/duplicate.json",
        (request) => {
          const body = parsePostData(request.requestBody);
          assert.strictEqual(body.theme_id, "5");
          // The edited outlet's draft rides along (the server-side round-trip is
          // covered by the request spec; here just confirm it's in the payload).
          assert.true(request.requestBody.includes("homepage-blocks"));
          assert.step("duplicated");
          return response({ theme_id: 42 });
        }
      );

      const result = await this.persistence.duplicateTheme(5);
      assert.strictEqual(result.theme_id, 42);
      assert.verifySteps(["duplicated"]);
    });

    test("createCustomizationComponent posts the drafts and returns the component id", async function (assert) {
      await enterEdited(this);

      pretender.post(
        "/admin/plugins/wireframe/customization-component.json",
        (request) => {
          const body = parsePostData(request.requestBody);
          assert.strictEqual(body.theme_id, "5");
          assert.true(request.requestBody.includes("homepage-blocks"));
          assert.step("componentized");
          return response({ theme_id: 99 });
        }
      );

      const result = await this.persistence.createCustomizationComponent(5);
      assert.strictEqual(result.theme_id, 99);
      assert.verifySteps(["componentized"]);
    });
  }
);
