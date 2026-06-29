import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { trackedObject } from "@ember/reactive/collections";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import BlockOutlet, {
  _renderBlocks,
  _resetOutletLayoutsForTesting,
} from "discourse/blocks/block-outlet";
import {
  registerBlock,
  withTestBlockRegistration,
} from "discourse/tests/helpers/block-testing";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, {
  parsePostData,
  response,
} from "discourse/tests/helpers/create-pretender";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import { setupBlockLayoutDraftsStub } from "../../helpers/stub-block-layout-drafts";

const PUBLISH_URL = "/admin/customize/block-layouts.json";
const DRAFTS_URL = "/admin/plugins/wireframe/block-layout-drafts.json";

@block("wf:nav-test-tile", { args: { title: { type: "string" } } })
class NavTestTile extends Component {
  <template>
    <div class="nav-tile">{{@title}}</div>
  </template>
}

// Marks an outlet as edited the way the inspector does: select one of its
// blocks and change an arg, then let the debounced write flush.
async function editTitle(editor, outlet, value) {
  const tile =
    editor.wireframeLayoutQuery.readResolvedLayout(outlet)?.[0]?.children?.[0];
  editor.selectBlock({
    key: `wf:nav-test-tile:${tile.__stableKey}`,
    name: "wf:nav-test-tile",
    args: { title: tile.args?.title },
    metadata: { args: { title: { type: "string" } } },
  });
  getOwner(editor)
    .lookup("service:wireframe-arg-edit")
    .updateSelectedArg("title", value);
  await settled();
}

module(
  "Integration | discourse-wireframe | service | navigation",
  function (hooks) {
    setupRenderingTest(hooks);
    setupBlockLayoutDraftsStub(hooks);

    hooks.beforeEach(function () {
      this.editor = getOwner(this).lookup("service:wireframe");
      this.editor.siteSettings.wireframe_enabled = true;
      logIn(getOwner(this));
    });

    hooks.afterEach(function () {
      this.editor.exit();
      _resetOutletLayoutsForTesting();
    });

    test("navigating to a page with a newly-mounted outlet materializes it", async function (assert) {
      const editor = this.editor;
      // We "enter" on a page that has `sidebar-blocks` but not `homepage-blocks`.
      // `homepage-blocks` has no layout, so it only becomes editable once it is
      // actually mounted (the build-from-scratch case).
      const state = trackedObject({ onHomepage: false });

      await render(
        <template>
          <BlockOutlet @name="sidebar-blocks" />
          {{#if state.onHomepage}}
            <BlockOutlet @name="homepage-blocks" />
          {{/if}}
        </template>
      );

      editor.enter();
      await settled();
      assert.false(
        editor.draftedOutletNames().includes("homepage-blocks"),
        "an off-page, layout-less outlet is not materialized at enter"
      );

      // Navigate to the homepage: its outlet mounts.
      state.onHomepage = true;
      await settled();
      assert.true(
        editor.blocks.mountedOutletNames().has("homepage-blocks"),
        "the new outlet is mounted after navigation"
      );

      // The `api.onPageChange` hook calls this after every navigation while the
      // editor is active.
      editor.rediscoverOutlets();
      await settled();
      assert.true(
        editor.draftedOutletNames().includes("homepage-blocks"),
        "rediscovery materializes the newly-mounted outlet so it can be built"
      );
    });

    test("the api.onPageChange hook rediscovers outlets when the page changes", async function (assert) {
      // Exercises the real wiring: the plugin's api-initializer registers
      // `api.onPageChange(() => editor.rediscoverOutlets())`, which fires on the
      // `page:changed` app event. Triggering that event stands in for a real SPA
      // navigation without needing a full router transition.
      const editor = this.editor;
      const appEvents = getOwner(this).lookup("service:app-events");
      const state = trackedObject({ onHomepage: false });

      await render(
        <template>
          <BlockOutlet @name="sidebar-blocks" />
          {{#if state.onHomepage}}
            <BlockOutlet @name="homepage-blocks" />
          {{/if}}
        </template>
      );

      editor.enter();
      await settled();
      assert.false(
        editor.draftedOutletNames().includes("homepage-blocks"),
        "not drafted before navigation"
      );

      // The new page renders (its outlet mounts), then the SPA fires the
      // navigation event the hook listens for.
      state.onHomepage = true;
      await settled();
      appEvents.trigger("page:changed", { url: "/", title: "Home" });
      await settled();

      assert.true(
        editor.draftedOutletNames().includes("homepage-blocks"),
        "the page:changed hook rediscovered and materialized the new outlet"
      );
    });

    test("rediscovering an untouched outlet does not mark it edited (no spurious publish)", async function (assert) {
      const editor = this.editor;
      const state = trackedObject({ onHomepage: false });

      await render(
        <template>
          <BlockOutlet @name="sidebar-blocks" />
          {{#if state.onHomepage}}
            <BlockOutlet @name="homepage-blocks" />
          {{/if}}
        </template>
      );

      editor.enter();
      await settled();
      state.onHomepage = true;
      await settled();
      editor.rediscoverOutlets();
      await settled();

      assert.true(
        editor.draftedOutletNames().includes("homepage-blocks"),
        "the outlet is seeded with an empty draft"
      );
      assert.false(
        editor.isOutletEdited("homepage-blocks"),
        "seeding a draft is not an edit"
      );

      // A publish must skip an outlet that was only seeded, never changed.
      pretender.post(PUBLISH_URL, (request) => {
        const body = parsePostData(request.requestBody);
        assert.step(`publish:${body.outlet_name}`);
        return response({});
      });
      await editor.publishEditedOutlets();
      assert.verifySteps([], "nothing is published when nothing was edited");
    });

    test("an outlet edited then navigated away from (unmounted) still publishes", async function (assert) {
      const editor = this.editor;
      // `homepage-blocks` has a real layout and is mounted; the editor is opened
      // on it, the user edits it, then navigates away so it unmounts.
      withTestBlockRegistration(() => registerBlock(NavTestTile));
      await _renderBlocks(
        "homepage-blocks",
        [{ block: NavTestTile, args: { title: "Original" } }],
        getOwner(this)
      );

      const state = trackedObject({ visible: true });
      await render(
        <template>
          {{#if state.visible}}
            <BlockOutlet @name="homepage-blocks" />
          {{/if}}
        </template>
      );

      editor.enter();
      await settled();
      await editTitle(editor, "homepage-blocks", "Edited");
      assert.true(
        editor.isOutletEdited("homepage-blocks"),
        "the outlet is edited"
      );

      // Navigate away: the outlet unmounts.
      state.visible = false;
      await settled();
      assert.false(
        editor.blocks.mountedOutletNames().has("homepage-blocks"),
        "the edited outlet is no longer mounted"
      );
      assert.true(
        editor.isOutletEdited("homepage-blocks"),
        "the edit survives unmounting"
      );

      // Publishing from another page still goes live for the edited outlet.
      pretender.post(PUBLISH_URL, (request) => {
        const body = parsePostData(request.requestBody);
        assert.step(`publish:${body.outlet_name}`);
        return response({});
      });
      // A successful publish discards the now-live draft.
      pretender.delete(DRAFTS_URL, () => response({ success: true }));
      await editor.publishEditedOutlets();
      assert.verifySteps(
        ["publish:homepage-blocks"],
        "the edited-but-unmounted outlet is still published"
      );
    });
  }
);
