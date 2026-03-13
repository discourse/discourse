import { fn } from "@ember/helper";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ToolbarPopupMenuOptions from "discourse/components/toolbar-popup-menu-options";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

function generateOptions(count) {
  return Array.from({ length: count }, (_, i) => ({
    name: `option-${i}`,
    icon: "cog",
    label: `Option ${i}`,
    translatedLabel: `Option ${i}`,
    condition: true,
  }));
}

module(
  "Integration | Component | toolbar-popup-menu-options",
  function (hooks) {
    setupRenderingTest(hooks);

    test("adds scroll classes when content overflows", async function (assert) {
      const content = generateOptions(30);

      await render(
        <template>
          <div style="height: 200px;">
            <ToolbarPopupMenuOptions
              @content={{content}}
              @class="options-content"
              @icon="cog"
              @onChange={{fn (mut this.value)}}
            />
          </div>
        </template>
      );

      await click(".fk-d-menu__trigger");

      const menu = document.querySelector(".fk-d-menu[class*='toolbar-menu']");
      assert.false(menu.classList.contains("--scroll-top"));
      assert.true(menu.classList.contains("--scroll-bottom"));
    });

    test("does not add scroll classes when content fits", async function (assert) {
      const content = generateOptions(2);

      await render(
        <template>
          <div>
            <ToolbarPopupMenuOptions
              @content={{content}}
              @class="options-content"
              @icon="cog"
              @onChange={{fn (mut this.value)}}
            />
          </div>
        </template>
      );

      await click(".fk-d-menu__trigger");

      const menu = document.querySelector(".fk-d-menu[class*='toolbar-menu']");
      assert.false(menu.classList.contains("--scroll-top"));
      assert.false(menu.classList.contains("--scroll-bottom"));
    });
  }
);
