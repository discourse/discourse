import { tracked } from "@glimmer/tracking";
import { click, fillIn, findAll, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import Site from "discourse/models/site";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import LargeCategoryListExample from "discourse/plugins/styleguide/discourse/components/examples/molecules/select/limits/large-category-list";

module(
  "Styleguide | Integration | large category list example",
  function (hooks) {
    setupRenderingTest(hooks);

    test("loads 10,000 sample categories only when asked", async function (assert) {
      const before = Site.current().categories.length;
      await render(<template><LargeCategoryListExample /></template>);

      assert.strictEqual(
        Site.current().categories.length,
        before,
        "nothing is added on render"
      );
      assert.dom(".d-select").doesNotExist("no picker before loading");

      await click(".btn");

      assert.strictEqual(
        Site.current().categories.length,
        before + 10000,
        "the sample tree is added to the site"
      );
      assert.dom(".d-select").exists("the picker renders");
    });

    test("searches the sample categories", async function (assert) {
      await render(<template><LargeCategoryListExample /></template>);
      await click(".btn");
      await click("[role='combobox']");
      await fillIn("[role='combobox']", "sample category 42-3-");

      const names = findAll("[role='option']").map((option) =>
        option.textContent.trim()
      );
      assert.true(names.length > 0, "matches are offered");
      assert.true(
        names.every((name) => name.includes("Sample category 42-3-")),
        "only matching sample categories are offered"
      );
    });

    test("removes the sample categories when it goes away", async function (assert) {
      class State {
        @tracked shown = true;
      }
      const state = new State();
      const before = Site.current().categories.length;
      await render(
        <template>
          {{#if state.shown}}
            <LargeCategoryListExample />
          {{/if}}
        </template>
      );
      await click(".btn");
      state.shown = false;
      await settled();

      assert.strictEqual(
        Site.current().categories.length,
        before,
        "the site is back to its own categories"
      );
      assert.false(
        Site.current().categories.some((category) =>
          category.name.startsWith(
            i18n("styleguide.sections.select.large_category_list_sample", {
              path: "",
            })
          )
        ),
        "no sample category remains"
      );
    });
  }
);
