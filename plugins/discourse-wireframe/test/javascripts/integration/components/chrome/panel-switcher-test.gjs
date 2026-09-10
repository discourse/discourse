import {
  click,
  find,
  focus,
  render,
  settled,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import EditorPanelSwitcher from "discourse/plugins/discourse-wireframe/discourse/components/editor/chrome/panel-switcher";

module(
  "Integration | discourse-wireframe | Component | EditorPanelSwitcher",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.owner.lookup("service:wireframe-rail").setLeftPanelTab("palette");
    });

    test("activity tabs pair selection with panel content and clear it on collapse", async function (assert) {
      const rail = this.owner.lookup("service:wireframe-rail");
      rail.setLeftPanelTab("palette");
      await render(
        <template>
          <EditorPanelSwitcher as |panel|><div
              data-panel={{panel}}
            >{{panel}}</div></EditorPanelSwitcher>
        </template>
      );

      const palette = '.wireframe-panel-switcher__entry[aria-label="Add"]';
      const outline = '.wireframe-panel-switcher__entry[aria-label="Layers"]';
      const tabpanel = '.wireframe-panel-switcher [role="tabpanel"]';

      assert
        .dom('.wireframe-panel-switcher [role="tablist"]')
        .hasAria("orientation", "vertical", "the entries form vertical tabs");
      assert.dom(palette).hasAria("selected", "true", "Add is selected");
      assert
        .dom(`${tabpanel} [data-panel]`)
        .hasText(
          "palette",
          "only the selected content is mounted inside the tabpanel"
        );
      assert
        .dom(tabpanel)
        .hasAttribute(
          "id",
          find(palette).getAttribute("aria-controls"),
          "the tab controls the actual panel"
        );
      assert
        .dom(tabpanel)
        .hasAria(
          "labelledby",
          find(palette).id,
          "the active tab names the panel"
        );

      await click(outline);
      assert
        .dom(outline)
        .hasAria("selected", "true", "Layers becomes selected");
      assert.dom(palette).hasAria("selected", "false", "Add is deselected");
      assert
        .dom(`${tabpanel} [data-panel]`)
        .hasText("outline", "the panel switches with selection");
      assert
        .dom('[data-panel="palette"]')
        .doesNotExist("inactive content is unmounted");
      assert
        .dom(tabpanel)
        .hasAria(
          "labelledby",
          find(outline).id,
          "the panel name follows selection"
        );

      await click(outline);
      assert.true(
        rail.leftCollapsed,
        "clicking the active tab collapses the rail"
      );
      assert
        .dom('.wireframe-panel-switcher [aria-selected="true"]')
        .doesNotExist("collapse leaves no selected tab");
      assert
        .dom("[data-panel]")
        .doesNotExist("collapse unmounts panel content");

      rail.showPalette();
      await settled();
      assert
        .dom(palette)
        .hasAria(
          "selected",
          "true",
          "external palette requests reopen and select Add"
        );
      assert
        .dom(`${tabpanel} [data-panel]`)
        .hasText("palette", "external requests restore panel content");
    });

    test("renders a vertical tablist with one tab per panel", async function (assert) {
      await render(<template><EditorPanelSwitcher /></template>);

      assert
        .dom(".wireframe-panel-switcher [role='tablist']")
        .hasAttribute(
          "aria-orientation",
          "vertical",
          "the group announces vertical navigation"
        );
      assert
        .dom(".wireframe-panel-switcher [role='tab']")
        .exists({ count: 3 }, "each panel has a tab");
    });

    test("arrow keys move between tabs without activating or including the collapse action", async function (assert) {
      await render(
        <template>
          <EditorPanelSwitcher as |panel|><div
              data-panel={{panel}}
            >{{panel}}</div></EditorPanelSwitcher>
        </template>
      );

      const entry = (n) => `.wireframe-panel-switcher__entry:nth-child(${n})`;
      const collapse = ".wireframe-panel-switcher__collapse";

      assert
        .dom(entry(1))
        .hasAttribute("tabindex", "0", "the selected tab is the entry point");
      assert
        .dom(entry(2))
        .hasAttribute(
          "tabindex",
          "-1",
          "other tabs are not separate tab stops"
        );
      assert
        .dom(collapse)
        .doesNotHaveAttribute(
          "tabindex",
          "collapse remains a native button tab stop"
        );
      assert
        .dom('[role="tablist"] .wireframe-panel-switcher__collapse')
        .doesNotExist("collapse is outside the tablist");

      await focus(entry(1));
      await triggerKeyEvent(entry(1), "keydown", "ArrowDown");
      assert.dom(entry(2)).isFocused("ArrowDown moves to the next entry");
      assert
        .dom(entry(2))
        .hasAttribute(
          "tabindex",
          "-1",
          "the tab stop stays on selection until activation"
        );

      assert
        .dom(entry(1))
        .hasAria("selected", "true", "arrow navigation does not activate");
      assert
        .dom("[data-panel]")
        .hasText("palette", "arrow navigation does not replace content");

      await triggerKeyEvent(entry(2), "keydown", "Enter");
      assert
        .dom(entry(2))
        .hasAria("selected", "true", "Enter activates the focused tab");
      assert.dom("[data-panel]").hasText("outline", "Enter switches the panel");
      await triggerKeyEvent(entry(2), "keydown", "End");
      assert.dom(entry(3)).isFocused("End reaches Issues, not collapse");
      await triggerKeyEvent(entry(3), "keydown", " ");
      assert.dom("[data-panel]").hasText("issues", "Space activates Issues");
      await triggerKeyEvent(entry(3), "keydown", "ArrowDown");
      assert.dom(entry(1)).isFocused("Down wraps to the first tab");
      await triggerKeyEvent(entry(1), "keydown", "ArrowUp");
      assert.dom(entry(3)).isFocused("Up wraps to the last tab");
      await triggerKeyEvent(entry(3), "keydown", "Home");
      assert.dom(entry(1)).isFocused("Home reaches Add");
    });

    test("an initially collapsed rail has no selected tab and can reopen by keyboard", async function (assert) {
      const rail = this.owner.lookup("service:wireframe-rail");
      rail.setLeftPanelTab("outline");
      rail.toggleLeftCollapsed();
      await render(<template><EditorPanelSwitcher /></template>);

      assert
        .dom('.wireframe-panel-switcher [aria-selected="true"]')
        .doesNotExist("initial collapse selects nothing");
      assert
        .dom(".wireframe-panel.--left")
        .doesNotExist("initial collapse mounts no panel");
      const first = '.wireframe-panel-switcher [role="tab"][tabindex="0"]';
      await focus(first);
      await triggerKeyEvent(first, "keydown", "Enter");
      assert.false(rail.leftCollapsed, "Enter expands the rail");
      assert
        .dom('.wireframe-panel-switcher [aria-selected="true"]')
        .isFocused("the activated tab retains focus");
    });

    test("the bottom chevron toggles collapse and reflects state", async function (assert) {
      const rail = this.owner.lookup("service:wireframe-rail");
      await render(<template><EditorPanelSwitcher /></template>);

      const collapse = ".wireframe-panel-switcher__collapse";
      assert.dom(collapse).hasAria("expanded", "true");

      await click(collapse);
      assert.true(rail.leftCollapsed, "collapses the wide panel");
      assert.dom(collapse).hasAria("expanded", "false");
      assert
        .dom(collapse)
        .isFocused("collapse retains focus outside the hidden panel");
      assert
        .dom('.wireframe-panel-switcher [aria-selected="true"]')
        .doesNotExist("no tab is selected while collapsed");

      await click(collapse);
      assert.false(rail.leftCollapsed, "expands again");
      assert.dom(collapse).hasAria("expanded", "true");
      assert
        .dom('.wireframe-panel-switcher__entry[data-d-tab="palette"]')
        .hasAria("selected", "true", "reopening restores the remembered tab");
    });

    test("the Issues entry shows a count badge only when issues exist", async function (assert) {
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
      assert
        .dom(".wireframe-panel-switcher__badge")
        .doesNotExist("no badge at zero");

      validation.issues = [
        { outletName: "a", blockKey: "x:1", blockName: "x", messages: ["m"] },
        { outletName: "a", blockKey: "y:2", blockName: "y", messages: ["m"] },
      ];
      await render(<template><EditorPanelSwitcher /></template>);
      assert
        .dom(".wireframe-panel-switcher__badge")
        .exists({ count: 1 })
        .hasText("2", "the badge shows the issue count");
      assert
        .dom('.wireframe-panel-switcher__entry[data-d-tab="issues"]')
        .hasAria(
          "label",
          i18n("wireframe.chrome.panel_issues_count", { count: 2 }),
          "the accessible name includes the live count"
        );
    });
  }
);
