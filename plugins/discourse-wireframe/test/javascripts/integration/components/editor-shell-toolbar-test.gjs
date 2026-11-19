import { getOwner } from "@ember/owner";
import {
  click,
  fillIn,
  render,
  settled,
  triggerKeyEvent,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import {
  _renderBlocks,
  _resetOutletLayoutsForTesting,
} from "discourse/blocks/block-outlet";
import Heading from "discourse/blocks/builtin/heading";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, {
  parsePostData,
  response,
} from "discourse/tests/helpers/create-pretender";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import EditorShell from "discourse/plugins/discourse-wireframe/discourse/components/editor/shell";
import { setupBlockLayoutDraftsStub } from "../../helpers/stub-block-layout-drafts";
import { engineOf, queryOf } from "../../helpers/wireframe-peers";

const OUTLET = "homepage-blocks";
const PUBLISH_URL = "/admin/customize/block-layouts.json";

function outletChildren(editor) {
  return queryOf(editor).readResolvedLayout(OUTLET)?.[0]?.children ?? [];
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
      this.editor = getOwner(this).lookup("service:wireframe-workspace");
      this.editor.siteSettings.wireframe_enabled = true;
      logIn(getOwner(this));
      // Re-look up after logging in so the editor sees the staff user and
      // `enter()` actually enables editing (matches the service-test setup).
      this.editor = getOwner(this).lookup("service:wireframe-workspace");
      // Pass an explicit theme id: there's no boot preload in a rendering test,
      // so the editor can't derive a default target and the toolbar's Save
      // button (which requires `activeThemeId` via `isDirty`) would stay disabled.
      this.editor.enter({ themeId: 5 });
      // The session publishes to a design; there's no boot preload to list one.
      getOwner(this)
        .lookup("service:wireframe-publish-target")
        .registerDesign(5, "Test design");
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
        .lookup("service:wireframe-inspector-args")
        .updateSelectedArg("text", "Edited");
      await settled();
    }

    test("Save is always enabled and saves without opening any panel", async function (assert) {
      let published = 0;
      pretender.post(PUBLISH_URL, () => {
        published++;
        return response({ version_token: "t1" });
      });
      await render(<template><EditorShell /></template>);

      assert
        .dom(".wireframe-btn-save")
        .isNotDisabled("Save is enabled with nothing edited");
      await click(".wireframe-btn-save");
      assert.strictEqual(published, 0, "nothing to save, so nothing is sent");

      await makeDirty(this.editor);
      await click(".wireframe-btn-save");
      assert.strictEqual(published, 1, "Save writes the layout straight away");
      assert
        .dom(".wireframe-review")
        .doesNotExist("there is no save-and-publish panel");
      assert
        .dom(".wireframe-saved-state")
        .exists("the indicator reads as saved once the edits are written");
    });

    test("the settings menu toggles dimming of non-editable regions", async function (assert) {
      await render(<template><EditorShell /></template>);
      const dimmed = () =>
        document.body.classList.contains("wireframe-active--dim-non-editable");
      const before = dimmed();

      await click(".wireframe-view-toggle");
      await click(".wireframe-view-settings .d-toggle-switch__checkbox");
      assert.notStrictEqual(dimmed(), before, "the toggle flips dimming");

      // The preference persists in local storage, so put it back.
      await click(".wireframe-view-settings .d-toggle-switch__checkbox");
      assert.strictEqual(dimmed(), before);
    });

    test("the status chip shows Published for the layout in use and changing it never saves", async function (assert) {
      let uninstalls = 0;
      let published = 0;
      pretender.put("/admin/plugins/wireframe/companion.json", (request) => {
        const body = parsePostData(request.requestBody);
        if (body.design_id === "") {
          uninstalls++;
        }
        return response({ success: "OK" });
      });
      pretender.post(PUBLISH_URL, () => {
        published++;
        return response({ version_token: "t1" });
      });
      getOwner(this.editor)
        .lookup("service:wireframe-publish-target")
        .setActiveTheme(5);
      Object.defineProperty(
        getOwner(this.editor).lookup("service:wireframe-publish-target"),
        "parentThemeId",
        { value: 1 }
      );
      await makeDirty(this.editor);
      await render(<template><EditorShell /></template>);

      assert
        .dom(".wireframe-status-chip")
        .hasClass("--published")
        .hasText("Published");

      await click(".wireframe-status-chip");
      assert
        .dom(".wireframe-status-menu__item[aria-current='true']")
        .hasClass("--published", "the current status is checked");
      assert
        .dom(".wireframe-status-menu__note")
        .exists("unsaved edits are called out in the menu");

      await click(".wireframe-status-menu__item.--draft");
      assert.strictEqual(
        uninstalls,
        1,
        "Draft takes the layout off the homepage"
      );
      assert.strictEqual(published, 0, "changing the status never saves");
      assert
        .dom(".wireframe-status-chip")
        .hasClass("--draft")
        .hasText("Unpublished");
      assert.dom(".wireframe-unsaved").exists("the edits are still unsaved");
    });

    test("Draft can be switched to Published once the layout has been saved", async function (assert) {
      const installs = [];
      pretender.put("/admin/plugins/wireframe/companion.json", (request) => {
        installs.push(parsePostData(request.requestBody).design_id);
        return response({ success: "OK" });
      });
      const target = getOwner(this.editor).lookup(
        "service:wireframe-publish-target"
      );
      target.registerDesign(5, "Test design", { inUse: false });
      target.setActiveTheme(5);
      Object.defineProperty(target, "parentThemeId", { value: 1 });

      await render(<template><EditorShell /></template>);
      assert.dom(".wireframe-status-chip").hasClass("--draft");

      await click(".wireframe-status-chip");
      await click(".wireframe-status-menu__item.--published");

      assert.deepEqual(installs, ["5"], "Published installs the saved layout");
      assert.dom(".wireframe-status-chip").hasClass("--published");
    });

    test("Published is unavailable until the layout has been saved once", async function (assert) {
      this.editor.exit();
      this.editor.enter({ themeId: -1 });

      await render(<template><EditorShell /></template>);
      assert.dom(".wireframe-status-chip").hasClass("--draft");

      await click(".wireframe-status-chip");
      assert
        .dom(".wireframe-status-menu__item.--published")
        .isDisabled("there is nothing saved to publish yet");
    });

    test("the unsaved changes count appears after an edit and can be discarded", async function (assert) {
      await render(<template><EditorShell /></template>);
      assert
        .dom(".wireframe-saved-state")
        .hasText("All changes saved", "nothing to report when clean");
      assert.dom(".wireframe-unsaved").doesNotExist();

      const [heading] = outletChildren(this.editor);
      getOwner(this.editor)
        .lookup("service:wireframe-block-mutations")
        .removeBlock(`heading:${heading.__stableKey}`);
      await settled();
      assert
        .dom(".wireframe-unsaved__label")
        .hasText("1 unsaved change", "the indicator counts the changes");

      // Rendering tests have no dialog holder, so confirm straight through.
      getOwner(this).lookup("service:dialog").confirm = ({ didConfirm }) =>
        didConfirm();
      await click(".wireframe-unsaved__discard");
      await waitUntil(() => !document.querySelector(".wireframe-unsaved"));
      assert
        .dom(".wireframe-unsaved")
        .doesNotExist("discarding clears the indicator");
      assert.false(
        engineOf(this.editor).isDirty,
        "the canvas is back to the last saved layout"
      );
    });

    test("saving clears the unsaved changes indicator", async function (assert) {
      pretender.post(PUBLISH_URL, () => response({ version_token: "t1" }));
      await makeDirty(this.editor);
      await render(<template><EditorShell /></template>);
      assert.dom(".wireframe-unsaved").exists();

      await click(".wireframe-btn-save");

      assert.dom(".wireframe-unsaved").doesNotExist();
      assert.dom(".wireframe-saved-state").hasText("Saved just now");
    });

    test("re-entering a theme that already has a design targets that design", async function (assert) {
      // The design lookup (on entry) returns the installed design, so the editor
      // re-points to it instead of treating the edits as an unsaved design.
      this.editor.exit();
      pretender.get("/admin/plugins/wireframe/companion.json", () =>
        response({
          companion_id: 7,
          designs: [{ id: 7, name: "Spring launch", active: true }],
        })
      );
      const theme = getOwner(this.editor).lookup(
        "service:wireframe-publish-target"
      );
      theme.registerDesign(7, "Spring launch");
      this.editor.enter({ themeId: -1 });

      await render(<template><EditorShell /></template>);

      assert.strictEqual(
        theme.activeThemeId,
        7,
        "activeThemeId re-points to the installed design"
      );
      assert.true(theme.hasDesign, "the design is a publishable target");
      assert
        .dom(".wireframe-design-title__text")
        .hasText("Spring launch", "the toolbar names the design");
    });

    test("the design name is renamed in place, and named before a design exists", async function (assert) {
      this.editor.exit();
      this.editor.enter({ themeId: -1 });

      await render(<template><EditorShell /></template>);
      assert
        .dom(".wireframe-design-title__text")
        .hasText("Untitled layout", "a placeholder names the unsaved design");

      await click(".wireframe-design-title__text");
      await fillIn(".wireframe-design-title__input", "Spring launch");
      await triggerKeyEvent(
        ".wireframe-design-title__input",
        "keydown",
        "Enter"
      );

      assert
        .dom(".wireframe-design-title__text")
        .hasText(
          "Spring launch",
          "the typed name is kept for the first publish"
        );
    });

    test("the design indicator opens a menu of designs with a New design button", async function (assert) {
      pretender.get("/admin/plugins/wireframe/companion.json", () =>
        response({
          companion_id: 5,
          designs: [
            { id: 5, name: "Test design", active: true },
            { id: 6, name: "Autumn sale", active: false },
          ],
        })
      );
      getOwner(this.editor)
        .lookup("service:wireframe-publish-target")
        .setActiveTheme(5);
      // No boot preload in a rendering test, so name the theme in use.
      Object.defineProperty(
        getOwner(this.editor).lookup("service:wireframe-publish-target"),
        "parentThemeId",
        { value: 1 }
      );

      await render(<template><EditorShell /></template>);
      await click(".wireframe-design-title__menu");

      assert
        .dom(".wireframe-design-switcher__design")
        .exists({ count: 2 }, "lists the available designs");
      assert.deepEqual(
        [
          ...document.querySelectorAll(".wireframe-design-switcher__design"),
        ].map((el) => el.textContent.trim()),
        ["Autumn sale", "Test design"],
        "lists designs alphabetically"
      );
      assert
        .dom(".wireframe-design-switcher__design.-selected")
        .hasText("Test design", "marks the active design as selected");
      assert
        .dom(".wireframe-design-switcher__design.-selected .d-icon")
        .doesNotExist("the selected design has no check icon");
      assert
        .dom(".wireframe-design-switcher__new")
        .exists("offers a New design button");
      assert
        .dom(".wireframe-design-switcher__manage")
        .exists("links to the designs list");
    });
  }
);
