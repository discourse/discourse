import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import {
  _renderBlocks,
  _resetOutletLayoutsForTesting,
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

@block("wf:drafts-test-tile", { args: { title: { type: "string" } } })
class DraftTile extends Component {
  <template>
    <div class="tile">{{@title}}</div>
  </template>
}

module(
  "Unit | Discourse Wireframe | service:wireframe-drafts",
  function (hooks) {
    setupTest(hooks);

    hooks.beforeEach(function () {
      this.editor = getOwner(this).lookup("service:wireframe");
      this.drafts = getOwner(this).lookup("service:wireframe-drafts");
    });

    hooks.afterEach(function () {
      _resetOutletLayoutsForTesting();
      this.editor.exit();
    });

    async function enterEdited(context) {
      withTestBlockRegistration(() => registerBlock(DraftTile));
      const layout = await _renderBlocks(
        "homepage-blocks",
        [{ block: DraftTile, args: { title: "Original" } }],
        getOwner(context)
      );
      const stableKey = layout[0].__stableKey;
      context.editor.wireframeSelection.selectBlock({
        key: `wf:drafts-test-tile:${stableKey}`,
        name: "wf:drafts-test-tile",
        args: { title: "Original" },
        metadata: { args: { title: { type: "string" } } },
      });
      getOwner(context.editor)
        .lookup("service:wireframe-arg-edit")
        .updateSelectedArg("title", "Edited");
      await settled();
    }

    test("saveDraftOutlet posts to the drafts endpoint with the base version token", async function (assert) {
      await enterEdited(this);

      pretender.post(DRAFTS_URL, (request) => {
        const body = parsePostData(request.requestBody);
        assert.strictEqual(body.theme_id, "5");
        assert.strictEqual(body.outlet_name, "homepage-blocks");
        // No live field has been observed, so the baseline is the empty token.
        assert.strictEqual(body.base_version_token, "");
        const payload = JSON.parse(body.layout_json);
        assert.strictEqual(payload.layout[0].args.title, "Edited");
        assert.step("drafted");
        return response({ success: true });
      });

      await this.drafts.saveDraftOutlet(5, "homepage-blocks");
      assert.verifySteps(["drafted"]);
    });

    test("saveDraftOutlet posts a system theme's negative id unchanged", async function (assert) {
      await enterEdited(this);

      pretender.post(DRAFTS_URL, (request) => {
        const body = parsePostData(request.requestBody);
        // Core system themes (Foundation, Horizon) have negative ids; the client
        // must forward them as-is rather than treating them as invalid.
        assert.strictEqual(body.theme_id, "-1");
        assert.step("drafted");
        return response({ success: true });
      });

      await this.drafts.saveDraftOutlet(-1, "homepage-blocks");
      assert.verifySteps(["drafted"]);
    });

    test("deleteDraft issues a DELETE and swallows transport errors", async function (assert) {
      pretender.delete(DRAFTS_URL, () => {
        assert.step("deleted");
        return response(500, {});
      });

      // Resolves (does not reject) even on a 500 — a failed cleanup is harmless.
      await this.drafts.deleteDraft(5, "homepage-blocks");
      assert.verifySteps(["deleted"]);
    });

    test("fetchDrafts parses rows and drops unparseable ones", async function (assert) {
      pretender.get(DRAFTS_URL, () =>
        response({
          drafts: [
            {
              theme_id: 5,
              outlet: "homepage-blocks",
              data: JSON.stringify({
                schema_version: 1,
                layout: [{ block: "x" }],
              }),
              base_version_token: "t1",
            },
            {
              theme_id: 5,
              outlet: "broken-blocks",
              data: "not json{",
              base_version_token: "t2",
            },
          ],
        })
      );

      const drafts = await this.drafts.fetchDrafts([5]);
      assert.strictEqual(drafts.length, 1, "the unparseable row is dropped");
      assert.strictEqual(drafts[0].outlet, "homepage-blocks");
      assert.strictEqual(drafts[0].baseVersionToken, "t1");
      assert.strictEqual(drafts[0].layout.length, 1);
    });

    test("fetchDrafts returns an empty list on a transport error", async function (assert) {
      pretender.get(DRAFTS_URL, () => response(500, {}));
      const drafts = await this.drafts.fetchDrafts([5]);
      assert.deepEqual(drafts, []);
    });
  }
);
