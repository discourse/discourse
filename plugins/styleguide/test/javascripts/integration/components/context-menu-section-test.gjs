import { click, find, findAll, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import DMenus from "discourse/float-kit/components/d-menus";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ContextMenuSection from "discourse/plugins/styleguide/discourse/components/sections/molecules/context-menu";

/**
 * Dispatches the same event the browser sends for both a right-click and the context-menu key,
 * so one helper covers the pointer and keyboard routes.
 */
async function contextMenu(element, { clientX = 20, clientY = 30 } = {}) {
  element.dispatchEvent(
    new MouseEvent("contextmenu", {
      bubbles: true,
      cancelable: true,
      clientX,
      clientY,
    })
  );
  await settled();
}

module(
  "Integration | Component | Styleguide | context menu section",
  function (hooks) {
    setupRenderingTest(hooks);

    test("styleguide-ctx: the section renders and its surface opens a menu", async function (assert) {
      await render(
        <template>
          <ContextMenuSection />
          <DMenus />
        </template>
      );

      const surface = find(".context-menu-demo__surface");
      assert.dom(surface).exists("the demo surface rendered");

      await contextMenu(surface);

      assert
        .dom(".fk-d-menu")
        .exists("right-clicking the documented surface opens its menu");
    });

    test("styleguide-ctx: the demo surfaces are reachable by keyboard", async function (assert) {
      await render(
        <template>
          <ContextMenuSection />
          <DMenus />
        </template>
      );

      // The context-menu key only reaches an element that can hold focus, so a demo built from
      // non-focusable divs would document a pattern nobody can operate without a mouse.
      const surfaces = findAll(".context-menu-demo__surface");
      assert.true(surfaces.length >= 3, "all three demo surfaces rendered");

      surfaces.forEach((surface) => {
        assert
          .dom(surface)
          .hasAttribute(
            "tabindex",
            "0",
            "every documented surface can take focus"
          );
      });
    });

    test("styleguide-ctx: closing returns focus to the surface the menu came from", async function (assert) {
      await render(
        <template>
          <ContextMenuSection />
          <DMenus />
        </template>
      );

      const surface = find(".context-menu-demo__surface");
      surface.focus();
      await contextMenu(surface);

      assert.true(
        find(".fk-d-menu").contains(document.activeElement),
        "focus moved into the open menu"
      );

      await click(".fk-d-menu button");

      assert
        .dom(surface)
        .isFocused(
          "focus came back to the surface rather than being stranded on the document"
        );
    });
  }
);
