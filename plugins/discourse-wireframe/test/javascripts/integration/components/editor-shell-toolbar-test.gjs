import { getOwner } from "@ember/owner";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import {
  _renderBlocks,
  _resetOutletLayoutsForTesting,
} from "discourse/blocks/block-outlet";
import Heading from "discourse/blocks/builtin/heading";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import EditorShell from "discourse/plugins/discourse-wireframe/discourse/components/editor/shell";
import { setupBlockLayoutDraftsStub } from "../../helpers/stub-block-layout-drafts";

const OUTLET = "homepage-blocks";
const DRAFTS_URL = "/admin/plugins/wireframe/block-layout-drafts.json";
const PUBLISH_URL = "/admin/customize/block-layouts.json";

function outletChildren(editor) {
  return editor.readResolvedLayout(OUTLET)?.[0]?.children ?? [];
}

module(
  "Integration | discourse-wireframe | Component | editor shell toolbar",
  function (hooks) {
    setupRenderingTest(hooks);
    setupBlockLayoutDraftsStub(hooks);

    hooks.beforeEach(async function () {
      await _renderBlocks(
        OUTLET,
        [{ block: Heading, args: { text: "Title" } }],
        getOwner(this)
      );
      this.editor = getOwner(this).lookup("service:wireframe");
      this.editor.siteSettings.wireframe_enabled = true;
      logIn(getOwner(this));
      // Re-look up after logging in so the editor sees the staff user and
      // `enter()` actually enables editing (matches the service-test setup).
      this.editor = getOwner(this).lookup("service:wireframe");
      // Pass an explicit theme id: there's no boot preload in a rendering test,
      // so the editor can't derive a default target and the toolbar's submit
      // control (which requires `activeThemeId`) would stay disabled.
      this.editor.enter({ themeId: 5 });
    });

    hooks.afterEach(function () {
      this.editor.exit();
      _resetOutletLayoutsForTesting();
    });

    // Edits the outlet's heading so the toolbar's submit control enables.
    async function makeDirty(editor) {
      const draft = outletChildren(editor);
      editor.selectBlock({
        key: `heading:${draft[0].__stableKey}`,
        name: "heading",
      });
      editor.updateSelectedArg("text", "Edited");
      await settled();
    }

    test("renders a Save draft primary with a Publish menu, disabled until dirty", async function (assert) {
      await render(<template><EditorShell /></template>);

      assert
        .dom(".wireframe-btn-save-draft")
        .hasText("Save draft", "the primary action is Save draft, not Publish");
      assert
        .dom(".wireframe-toolbar-publish-trigger")
        .exists("the Publish menu trigger renders alongside it");
      // Nothing edited yet → the whole control is disabled.
      assert
        .dom(".wireframe-btn-save-draft")
        .isDisabled("Save draft is disabled with nothing edited");
    });

    test("Save draft drafts the edited outlets without publishing; the menu publishes", async function (assert) {
      await makeDirty(this.editor);

      let drafted = false;
      let published = false;
      pretender.post(DRAFTS_URL, () => {
        drafted = true;
        return response({ success: true });
      });
      pretender.post(PUBLISH_URL, () => {
        published = true;
        return response({ version_token: "t1" });
      });
      // A successful publish cleans up the now-redundant draft.
      pretender.delete(DRAFTS_URL, () => response({ success: true }));

      await render(<template><EditorShell /></template>);

      await click(".wireframe-btn-save-draft");
      assert.true(drafted, "clicking Save draft hits the drafts endpoint");
      assert.false(published, "Save draft never writes the live field");

      await click(".wireframe-toolbar-publish-trigger");
      await click(".wireframe-toolbar-publish-content .wireframe-btn-publish");
      assert.true(published, "the Publish menu item writes the live field");
    });

    test("for a core system theme, Save draft works but direct Publish is disabled", async function (assert) {
      // Re-enter bound to a system theme (negative id). Save draft stays
      // available; direct Publish is disabled in favour of the per-outlet
      // companion-component path in the inspector.
      this.editor.exit();
      this.editor.enter({ themeId: -1 });
      await makeDirty(this.editor);

      await render(<template><EditorShell /></template>);

      assert
        .dom(".wireframe-btn-save-draft")
        .isNotDisabled("Save draft works for a system theme");

      await click(".wireframe-toolbar-publish-trigger");
      assert
        .dom(".wireframe-toolbar-publish-content .wireframe-btn-publish")
        .isDisabled("direct Publish is disabled for a system theme");
    });

    test("Save draft disables after a successful save and re-enables on the next edit", async function (assert) {
      await makeDirty(this.editor);
      pretender.post(DRAFTS_URL, () => response({ success: true }));

      await render(<template><EditorShell /></template>);

      assert
        .dom(".wireframe-btn-save-draft")
        .isNotDisabled("enabled while there are unsaved edits");

      await click(".wireframe-btn-save-draft");
      assert
        .dom(".wireframe-btn-save-draft")
        .isDisabled("disabled once the current edits are drafted");

      // A further edit re-enables it.
      const draft = outletChildren(this.editor);
      this.editor.selectBlock({
        key: `heading:${draft[0].__stableKey}`,
        name: "heading",
      });
      this.editor.updateSelectedArg("text", "Edited again");
      await settled();

      assert
        .dom(".wireframe-btn-save-draft")
        .isNotDisabled("re-enabled after a new edit");
    });

    test("opening with a matching saved draft starts with Save draft disabled", async function (assert) {
      // The shared beforeEach already entered (and ran draft hydration) with no
      // drafts. Re-enter with a matching saved draft mocked BEFORE enter, so this
      // hydration re-seeds it. A real (pretender) request is tracked by
      // `settled()`, so `render()` deterministically waits for the re-seed — no
      // polling. The re-seeded draft reflects what's persisted, so there's
      // nothing new to save yet even though the outlet ends up marked edited.
      this.editor.exit();
      pretender.get(DRAFTS_URL, () =>
        response({
          drafts: [
            {
              theme_id: 5,
              outlet: OUTLET,
              data: JSON.stringify({
                schema_version: 1,
                layout: [{ block: "heading", args: { text: "Drafted" } }],
              }),
              base_version_token: "",
            },
          ],
        })
      );
      this.editor.enter({ themeId: 5 });

      await render(<template><EditorShell /></template>);

      assert.true(
        this.editor.isDirty,
        "the hydrated draft marks the outlet edited"
      );
      assert
        .dom(".wireframe-btn-save-draft")
        .isDisabled("a freshly hydrated draft has nothing new to save");
    });
  }
);
