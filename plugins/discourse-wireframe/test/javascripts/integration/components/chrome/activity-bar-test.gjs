import { click, render } from "@ember/test-helpers";
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

    test("aria-pressed marks the open panel; collapsing clears it", async function (assert) {
      const rail = this.owner.lookup("service:wireframe-rail");
      await render(<template><ActivityBar /></template>);

      const entries = ".wireframe-activity-bar__entry";

      // Palette is the default open panel.
      assert.dom(`${entries}:nth-child(1)`).hasAria("pressed", "true");
      assert.dom(`${entries}:nth-child(2)`).hasAria("pressed", "false");

      // Activating Layers (outline) opens it and presses its entry.
      await click(`${entries}:nth-child(2)`);
      assert.strictEqual(rail.leftPanelTab, "outline");
      assert.dom(`${entries}:nth-child(2)`).hasAria("pressed", "true");
      assert.dom(`${entries}:nth-child(1)`).hasAria("pressed", "false");

      // Re-activating the open panel collapses the rail — nothing reads pressed.
      await click(`${entries}:nth-child(2)`);
      assert.true(rail.leftCollapsed);
      assert.dom(`${entries}:nth-child(2)`).hasAria("pressed", "false");
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
  }
);
