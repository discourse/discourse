import { focus, render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import NestedSortSelector from "discourse/components/nested/sort-selector";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dSelect from "discourse/tests/helpers/d-select-helper";
import { i18n } from "discourse-i18n";

module(
  "Integration | Component | nested/sort-selector | new select controls",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.enable_new_select_controls = true;
      this.changes = [];
      this.onChange = (sort) => this.changes.push(sort);
    });

    test("is named by its Sort by label and shows the current sort", async function (assert) {
      await render(
        <template>
          <NestedSortSelector @current="new" @onChange={{this.onChange}} />
        </template>
      );

      const [labelId] = dSelect()
        .element()
        .getAttribute("aria-labelledby")
        .split(" ");
      assert.dom(`#${labelId}`).includesText(i18n("nested_replies.sort.label"));
      assert.dSelect().hasValue("new");
      assert.dSelect().hasLabel(i18n("nested_replies.sort.new"));
    });

    test("offers Hot only when the hot sort is enabled", async function (assert) {
      await render(
        <template>
          <NestedSortSelector @current="top" @onChange={{this.onChange}} />
        </template>
      );
      await dSelect().open();

      assert.dSelect().hasOptions(["top", "new", "old"]);

      this.siteSettings.nested_replies_hot_sort_enabled = true;
      await render(
        <template>
          <NestedSortSelector @current="top" @onChange={{this.onChange}} />
        </template>
      );
      await dSelect().open();

      assert.dSelect().hasOptions(["top", "hot", "new", "old"]);
    });

    test("reports a new sort, and nothing when the current one is picked", async function (assert) {
      await render(
        <template>
          <NestedSortSelector @current="top" @onChange={{this.onChange}} />
        </template>
      );
      await dSelect().select("top");
      await dSelect().select("old");

      assert.deepEqual(this.changes, ["old"]);
    });

    test("keeps the sort when Backspace is pressed on it", async function (assert) {
      await render(
        <template>
          <NestedSortSelector @current="top" @onChange={{this.onChange}} />
        </template>
      );
      await focus(dSelect().element());
      await triggerKeyEvent(dSelect().element(), "keydown", "Backspace");

      assert.deepEqual(this.changes, [], "the sort is never emptied");
    });
  }
);
