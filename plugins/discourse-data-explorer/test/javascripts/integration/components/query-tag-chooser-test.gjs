import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dSelect from "discourse/tests/helpers/d-select-helper";
import { i18n } from "discourse-i18n";
import QueryTagChooser from "discourse/plugins/discourse-data-explorer/discourse/components/query-tag-chooser";

function optionNames() {
  return [...document.querySelectorAll("[role='option']")].map(
    (option) => option.dataset.name
  );
}

module(
  "Integration | Component | query-tag-chooser with the new select controls",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.enable_new_select_controls = true;
      this.availableTags = ["default", "staff", "ops", "custom"];
      this.value = ["Ops", "custom"];
      this.automaticTags = ["custom"];
      this.changes = [];
      this.onChange = (tags) => this.changes.push([...tags]);
    });

    test("is named by the label it points at", async function (assert) {
      await render(
        <template>
          <span id="query-tags-label">Tags</span>
          <QueryTagChooser
            @ariaLabelledBy="query-tags-label"
            @automaticTags={{this.automaticTags}}
            @availableTags={{this.availableTags}}
            @onChange={{this.onChange}}
            @value={{this.value}}
          />
        </template>
      );

      const labelledBy = document
        .querySelector(".query-tag-chooser [role='combobox']")
        ?.getAttribute("aria-labelledby");
      assert.true(
        (labelledBy ?? "").split(" ").includes("query-tags-label"),
        `the combobox is labelled by the caption (aria-labelledby="${labelledBy}")`
      );
    });

    test("offers the tags anyone can pick, once each, in order", async function (assert) {
      await render(
        <template>
          <QueryTagChooser
            @automaticTags={{this.automaticTags}}
            @availableTags={{this.availableTags}}
            @onChange={{this.onChange}}
            @value={{this.value}}
          />
        </template>
      );

      await dSelect(".query-tag-chooser").open();
      assert.deepEqual(
        optionNames(),
        ["custom", "Ops", "staff"],
        "the reserved default tag isn't offered, and ops is offered as held"
      );
    });

    test("keeps automatic tags, which can't be removed", async function (assert) {
      await render(
        <template>
          <QueryTagChooser
            @automaticTags={{this.automaticTags}}
            @availableTags={{this.availableTags}}
            @onChange={{this.onChange}}
            @value={{this.value}}
          />
        </template>
      );

      assert.dom(".d-select__chip[data-value='custom']").hasClass("--locked");
      assert
        .dom(".d-select__chip[data-value='custom']")
        .includesText(i18n("explorer.automatic_tag_mandatory"));
      assert
        .dom(".d-select__chip[data-value='Ops']")
        .doesNotHaveClass("--locked");
    });

    test("creates new tags, but never a reserved one", async function (assert) {
      await render(
        <template>
          <QueryTagChooser
            @automaticTags={{this.automaticTags}}
            @availableTags={{this.availableTags}}
            @onChange={{this.onChange}}
            @value={{this.value}}
          />
        </template>
      );

      const tags = dSelect(".query-tag-chooser");
      await tags.search("Default");
      assert
        .dom("[role='option']")
        .doesNotExist("the reserved default tag can't be created");

      await tags.search("Monthly");
      await tags.select("Monthly");
      assert.deepEqual(this.changes, [["Ops", "custom", "Monthly"]]);
    });
  }
);
