import { click, focus, render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ActivityBar from "discourse/plugins/discourse-wireframe/discourse/components/editor/chrome/activity-bar";

module(
  "Integration | discourse-wireframe | Component | activity-bar",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders a vertical toolbar with one toggle per panel", async function (assert) {
      await render(<template><ActivityBar /></template>);

      assert
        .dom(".wireframe-activity-bar[role='toolbar']")
        .hasAttribute("aria-orientation", "vertical");
      assert.dom(".wireframe-activity-bar__entry").exists({ count: 3 });
    });

    test("arrow keys rove vertically across entries and the collapse chevron", async function (assert) {
      await render(<template><ActivityBar /></template>);

      const entry = (n) =>
        `.wireframe-activity-bar__entry-wrap:nth-child(${n}) .wireframe-activity-bar__entry`;
      const collapse = ".wireframe-activity-bar__collapse";

      // One tab stop across the whole strip: the first entry, then -1 elsewhere.
      assert.dom(entry(1)).hasAttribute("tabindex", "0");
      assert.dom(entry(2)).hasAttribute("tabindex", "-1");
      assert.dom(collapse).hasAttribute("tabindex", "-1");

      await focus(entry(1));
      await triggerKeyEvent(entry(1), "keydown", "ArrowDown");
      assert.dom(entry(2)).isFocused("ArrowDown moves to the next entry");
      assert
        .dom(entry(2))
        .hasAttribute("tabindex", "0", "the tab stop follows");

      // End jumps to the last item in the rove — the bottom collapse chevron.
      await triggerKeyEvent(entry(2), "keydown", "End");
      assert.dom(collapse).isFocused("End reaches the collapse chevron");
    });

    test("aria-pressed marks the open panel; collapsing clears it", async function (assert) {
      const rail = this.owner.lookup("service:wireframe-rail");
      await render(<template><ActivityBar /></template>);

      // Each entry button lives inside its own wrap; address them through it.
      const entry = (n) =>
        `.wireframe-activity-bar__entry-wrap:nth-child(${n}) .wireframe-activity-bar__entry`;

      // Palette is the default open panel.
      assert.dom(entry(1)).hasAria("pressed", "true");
      assert.dom(entry(2)).hasAria("pressed", "false");

      // Activating Layers (outline) opens it and presses its entry.
      await click(entry(2));
      assert.strictEqual(rail.leftPanelTab, "outline");
      assert.dom(entry(2)).hasAria("pressed", "true");
      assert.dom(entry(1)).hasAria("pressed", "false");

      // Re-activating the open panel collapses the rail — nothing reads pressed.
      await click(entry(2));
      assert.true(rail.leftCollapsed);
      assert.dom(entry(2)).hasAria("pressed", "false");
    });

    test("the bottom chevron toggles collapse and reflects state", async function (assert) {
      const rail = this.owner.lookup("service:wireframe-rail");
      await render(<template><ActivityBar /></template>);

      const collapse = ".wireframe-activity-bar__collapse";
      assert.dom(collapse).hasAria("expanded", "true");

      await click(collapse);
      assert.true(rail.leftCollapsed, "collapses the wide panel");
      assert.dom(collapse).hasAria("expanded", "false");

      await click(collapse);
      assert.false(rail.leftCollapsed, "expands again");
      assert.dom(collapse).hasAria("expanded", "true");
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

      await render(<template><ActivityBar /></template>);
      assert
        .dom(".wireframe-activity-bar__badge")
        .doesNotExist("no badge at zero");

      validation.issues = [
        { outletName: "a", blockKey: "x:1", blockName: "x", messages: ["m"] },
        { outletName: "a", blockKey: "y:2", blockName: "y", messages: ["m"] },
      ];
      await render(<template><ActivityBar /></template>);
      assert
        .dom(".wireframe-activity-bar__badge")
        .exists({ count: 1 })
        .hasText("2", "the badge shows the issue count");
    });
  }
);
