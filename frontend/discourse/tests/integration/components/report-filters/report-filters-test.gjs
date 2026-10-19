import { tracked } from "@glimmer/tracking";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import Bool from "discourse/admin/components/report-filters/bool";
import List from "discourse/admin/components/report-filters/list";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";

module("Integration | Component | ReportFilters", function (hooks) {
  setupRenderingTest(hooks);

  test("a bool filter applies the toggled value and follows the report", async function (assert) {
    const filter = tracked({ id: "include_subcategories", default: false });
    const applied = [];
    const applyFilter = (id, value) => applied.push([id, value]);

    await render(
      <template>
        <Bool @applyFilter={{applyFilter}} @filter={{filter.value}} />
      </template>
    );

    assert.dom("input[type='checkbox']").isNotChecked();

    await click("input[type='checkbox']");

    assert.deepEqual(
      applied,
      [["include_subcategories", true]],
      "applies the checked value"
    );

    filter.value = { id: "include_subcategories", default: true };
    await settled();

    assert
      .dom("input[type='checkbox']")
      .isChecked("shows the value the report applied");

    filter.value = { id: "include_subcategories", default: false };
    await settled();

    assert
      .dom("input[type='checkbox']")
      .isNotChecked("follows the report when it changes the value");
  });

  test("a list filter applies the picked choice", async function (assert) {
    const applied = [];
    const applyFilter = (id, value) => applied.push([id, value]);
    const filter = {
      id: "flag_type",
      default: null,
      choices: [
        { id: "spam", name: "Spam" },
        { id: "off_topic", name: "Off topic" },
      ],
    };

    await render(
      <template>
        <List @applyFilter={{applyFilter}} @filter={{filter}} />
      </template>
    );

    await selectKit().expand();
    await selectKit().selectRowByValue("spam");

    assert.deepEqual(applied, [["flag_type", "spam"]]);
  });
});
