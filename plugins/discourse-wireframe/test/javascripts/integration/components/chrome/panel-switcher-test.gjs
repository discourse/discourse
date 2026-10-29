import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import EditorPanelSwitcher from "discourse/plugins/discourse-wireframe/discourse/components/editor/chrome/panel-switcher";

const SECTIONS = ".wireframe-panel-switcher__sections";

function input(panel) {
  return `${SECTIONS} .d-segmented-control__input[value="${panel}"]`;
}

function segment(panel) {
  return `${SECTIONS} .d-segmented-control__label:has(input[value="${panel}"])`;
}

module(
  "Integration | discourse-wireframe | Component | EditorPanelSwitcher",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.owner.lookup("service:wireframe-rail").setLeftPanelTab("palette");
    });

    test("names the sections in a segmented control with the active one checked", async function (assert) {
      await render(
        <template>
          <EditorPanelSwitcher as |panel|><div
              data-panel={{panel}}
            >{{panel}}</div></EditorPanelSwitcher>
        </template>
      );

      assert
        .dom(".wireframe-panel-switcher.wireframe-panel.--left")
        .exists("the switcher is the left panel itself");
      assert
        .dom(`.wireframe-panel-switcher > .panel-header ${SECTIONS}`)
        .exists("the control sits in the panel header");
      assert
        .dom(`${SECTIONS} .d-segmented-control__legend`)
        .hasText("Editor panels", "the group is named");
      assert
        .dom(`${SECTIONS} .d-segmented-control__input`)
        .exists({ count: 3 }, "one segment per section");
      assert.dom(segment("palette")).hasText("Add");
      assert.dom(segment("outline")).hasText("Layers");
      assert.dom(segment("issues")).hasText("Issues");
      assert.dom(input("palette")).isChecked("Add starts selected");
      assert.dom(input("outline")).isNotChecked();
      assert
        .dom(".wireframe-panel-switcher .panel-body [data-panel]")
        .hasText("palette", "the active section's content renders");
      assert
        .dom(".wireframe-panel-switcher__activity-bar, [role='tablist']")
        .doesNotExist("there is no icon rail");
    });

    test("selecting a section switches the content and the service", async function (assert) {
      const rail = this.owner.lookup("service:wireframe-rail");
      await render(
        <template>
          <EditorPanelSwitcher as |panel|><div
              data-panel={{panel}}
            >{{panel}}</div></EditorPanelSwitcher>
        </template>
      );

      await click(segment("outline"));

      assert.dom(input("outline")).isChecked("Layers becomes selected");
      assert.dom(input("palette")).isNotChecked("Add is deselected");
      assert.dom("[data-panel]").hasText("outline", "the content switches");
      assert
        .dom('[data-panel="palette"]')
        .doesNotExist("inactive content is unmounted");
      assert.strictEqual(
        rail.leftPanelTab,
        "outline",
        "the selection lives on the rail service"
      );

      await click(segment("outline"));
      assert.dom(input("outline")).isChecked("re-selecting changes nothing");
      assert
        .dom("[data-panel]")
        .hasText("outline", "the panel stays open on re-selection");
    });

    test("follows section changes made through the service", async function (assert) {
      const rail = this.owner.lookup("service:wireframe-rail");
      await render(
        <template>
          <EditorPanelSwitcher as |panel|><div
              data-panel={{panel}}
            >{{panel}}</div></EditorPanelSwitcher>
        </template>
      );

      rail.setLeftPanelTab("issues");
      await settled();
      assert.dom(input("issues")).isChecked("the control follows the service");
      assert.dom("[data-panel]").hasText("issues");

      rail.showPalette();
      await settled();
      assert
        .dom(input("palette"))
        .isChecked("external palette requests select Add");
      assert.dom("[data-panel]").hasText("palette");
    });

    test("the Issues segment carries the live count", async function (assert) {
      class StubValidation {
        issues = [];

        get validationIssues() {
          return this.issues;
        }
      }
      const validation = new StubValidation();
      this.owner.register("service:wireframe-validation", validation, {
        instantiate: false,
      });

      await render(<template><EditorPanelSwitcher /></template>);
      assert.dom(segment("issues")).hasText("Issues", "no count at zero");
      assert
        .dom(input("issues"))
        .doesNotHaveAttribute(
          "aria-label",
          "the visible text is the accessible name at zero"
        );

      validation.issues = [
        { outletName: "a", blockKey: "x:1", blockName: "x", messages: ["m"] },
        { outletName: "a", blockKey: "y:2", blockName: "y", messages: ["m"] },
      ];
      await render(<template><EditorPanelSwitcher /></template>);
      assert
        .dom(segment("issues"))
        .hasText("Issues (2)", "the segment shows the issue count");
      assert
        .dom(input("issues"))
        .hasAttribute(
          "aria-label",
          i18n("wireframe.chrome.panel_issues_count", { count: 2 }),
          "the accessible name spells the count out"
        );
    });
  }
);
