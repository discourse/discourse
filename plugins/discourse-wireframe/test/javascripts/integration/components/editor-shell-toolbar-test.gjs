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
  return (
    editor.wireframeLayoutQuery.readResolvedLayout(OUTLET)?.[0]?.children ?? []
  );
}

module(
  "Integration | discourse-wireframe | Component | editor shell save flow",
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
      // so the editor can't derive a default target and the toolbar's Save
      // button (which requires `activeThemeId` via `isDirty`) would stay disabled.
      this.editor.enter({ themeId: 5 });
    });

    hooks.afterEach(function () {
      this.editor.exit();
      _resetOutletLayoutsForTesting();
    });

    // Edits the outlet's heading so the toolbar's Save button enables.
    async function makeDirty(editor) {
      const draft = outletChildren(editor);
      editor.wireframeSelection.selectBlock({
        key: `heading:${draft[0].__stableKey}`,
        name: "heading",
      });
      getOwner(editor)
        .lookup("service:wireframe-arg-edit")
        .updateSelectedArg("text", "Edited");
      await settled();
    }

    test("the toolbar Save button is disabled until dirty and opens the review drawer", async function (assert) {
      await render(<template><EditorShell /></template>);

      assert
        .dom(".wireframe-btn-save")
        .isDisabled("Save is disabled with nothing edited");
      assert
        .dom(".wireframe-review")
        .doesNotExist("the review drawer is closed initially");

      await makeDirty(this.editor);
      assert
        .dom(".wireframe-btn-save")
        .isNotDisabled("Save enables once there are edits");

      await click(".wireframe-btn-save");
      assert
        .dom(".wireframe-review")
        .exists("clicking Save opens the review drawer");
    });

    test("the drawer's Save draft drafts the edited outlets without publishing; Publish writes the live field", async function (assert) {
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
      await click(".wireframe-btn-save");

      await click(".wireframe-review__save-draft");
      assert.true(drafted, "Save draft hits the drafts endpoint");
      assert.false(published, "Save draft never writes the live field");

      await click(".wireframe-review__publish");
      assert.true(published, "Publish writes the live field");
    });

    test("for a core system theme, Save draft works but Publish is disabled and the companion path is offered", async function (assert) {
      // Re-enter bound to a system theme (negative id). Save draft stays
      // available; direct Publish is disabled in favour of the companion-
      // component escape hatch.
      this.editor.exit();
      this.editor.enter({ themeId: -1 });
      await makeDirty(this.editor);

      await render(<template><EditorShell /></template>);
      await click(".wireframe-btn-save");

      assert
        .dom(".wireframe-review__save-draft")
        .isNotDisabled("Save draft works for a system theme");
      assert
        .dom(".wireframe-review__publish")
        .isDisabled("direct Publish is disabled for a system theme");
      assert
        .dom(".wireframe-review__create-component")
        .exists("the companion-component escape hatch is offered instead");
    });

    test("re-entering a non-publishable theme that already has a companion targets the companion", async function (assert) {
      // The companion lookup (on entry) returns an existing companion id, so the
      // editor re-points to it instead of re-prompting to set one up.
      this.editor.exit();
      pretender.get("/admin/plugins/wireframe/companion.json", () =>
        response({ companion_id: 7 })
      );
      this.editor.enter({ themeId: -1 });

      await render(<template><EditorShell /></template>);

      const theme = getOwner(this.editor).lookup("service:wireframe-theme");
      assert.strictEqual(
        theme.activeThemeId,
        7,
        "activeThemeId re-points to the existing companion"
      );
      assert.true(
        theme.activeThemeTarget.publishable,
        "the companion is a publishable target"
      );
      assert
        .dom(".wireframe-blocked-callout")
        .doesNotExist("no set-up callout when a companion already exists");
    });

    test("the drawer's Save draft disables after a successful save and re-enables on the next edit", async function (assert) {
      await makeDirty(this.editor);
      pretender.post(DRAFTS_URL, () => response({ success: true }));

      await render(<template><EditorShell /></template>);
      await click(".wireframe-btn-save");

      assert
        .dom(".wireframe-review__save-draft")
        .isNotDisabled("enabled while there are unsaved edits");

      await click(".wireframe-review__save-draft");
      assert
        .dom(".wireframe-review__save-draft")
        .isDisabled("disabled once the current edits are drafted");

      // A further edit re-enables it.
      const draft = outletChildren(this.editor);
      this.editor.wireframeSelection.selectBlock({
        key: `heading:${draft[0].__stableKey}`,
        name: "heading",
      });
      getOwner(this.editor)
        .lookup("service:wireframe-arg-edit")
        .updateSelectedArg("text", "Edited again");
      await settled();

      assert
        .dom(".wireframe-review__save-draft")
        .isNotDisabled("re-enabled after a new edit");
    });

    test("opening with a matching saved draft starts the drawer's Save draft disabled", async function (assert) {
      // The shared beforeEach already entered (and ran draft hydration) with no
      // drafts. Re-enter with a matching saved draft mocked BEFORE enter, so this
      // hydration re-seeds it. The re-seeded draft reflects what's persisted, so
      // there's nothing new to save yet even though the outlet ends up edited.
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
        this.editor.wireframeEditEngine.isDirty,
        "the hydrated draft marks the outlet edited"
      );

      await click(".wireframe-btn-save");
      assert
        .dom(".wireframe-review__save-draft")
        .isDisabled("a freshly hydrated draft has nothing new to save");
    });

    test("the Changes tab renders a per-outlet change summary", async function (assert) {
      await makeDirty(this.editor);

      await render(<template><EditorShell /></template>);
      await click(".wireframe-btn-save");
      await click(".wireframe-review__tab.--active + .wireframe-review__tab");

      assert
        .dom(".wireframe-review__change")
        .exists("the Changes tab lists the edited outlet");
      assert
        .dom(".wireframe-review__change-counts")
        .exists("with a change summary");
    });

    test("a draft edited back to match the published layout is still saveable", async function (assert) {
      // Code layer (the "published" baseline) is one Heading "Title". Seed a saved
      // draft that adds a second block, so the hydrated draft differs from it.
      this.editor.exit();
      pretender.get(DRAFTS_URL, () =>
        response({
          drafts: [
            {
              theme_id: 5,
              outlet: OUTLET,
              data: JSON.stringify({
                schema_version: 1,
                layout: [
                  { block: "heading", args: { text: "Title" } },
                  { block: "heading", args: { text: "Extra" } },
                ],
              }),
              base_version_token: "",
            },
          ],
        })
      );
      this.editor.enter({ themeId: 5 });
      await render(<template><EditorShell /></template>);

      assert.strictEqual(
        outletChildren(this.editor).length,
        2,
        "the saved draft hydrated with two blocks"
      );

      // Delete the extra block so the canvas now matches the published one-block
      // layout — but the persisted draft still has two blocks.
      const extra = outletChildren(this.editor)[1];
      this.owner
        .lookup("service:wireframe-block-mutations")
        .removeBlock(`heading:${extra.__stableKey}`);
      await settled();

      assert.strictEqual(
        outletChildren(this.editor).length,
        1,
        "back to the published one-block layout"
      );
      assert.true(
        this.owner.lookup("service:wireframe-staging").hasUnsavedDraftEdits,
        "the persisted draft still differs from the canvas, so there are unsaved draft edits"
      );
      assert
        .dom(".wireframe-btn-save")
        .isNotDisabled("Save stays enabled so the draft can be updated");

      // Saving must actually write the draft (not silently no-op) and then read
      // clean.
      let drafted = false;
      pretender.post(DRAFTS_URL, () => {
        drafted = true;
        return response({ success: true });
      });

      await click(".wireframe-btn-save");
      await click(".wireframe-review__save-draft");

      assert.true(drafted, "Save draft writes the updated draft to the server");
      assert.false(
        this.owner.lookup("service:wireframe-staging").hasUnsavedDraftEdits,
        "after saving, the draft baseline matches the canvas"
      );
    });
  }
);
