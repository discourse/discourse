import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dSelect from "discourse/tests/helpers/d-select-helper";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import AutomationField from "discourse/plugins/automation/admin/components/automation-field";
import AutomationFabricators from "discourse/plugins/automation/admin/lib/fabricators";

module("Integration | Component | DaTagsField", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.automation = new AutomationFabricators(getOwner(this)).automation();
  });

  test("set value", async function (assert) {
    this.field = new AutomationFabricators(getOwner(this)).field({
      component: "tags",
    });

    await render(
      <template>
        <AutomationField
          @automation={{this.automation}}
          @field={{this.field}}
        />
      </template>
    );

    await selectKit().expand();
    await selectKit().selectRowByName("monkey");

    assert.deepEqual(this.field.metadata.value, ["monkey"]);
  });

  test("empty tags", async function (assert) {
    this.field = new AutomationFabricators(getOwner(this)).field({
      component: "tags",
    });

    await render(
      <template>
        <AutomationField
          @automation={{this.automation}}
          @field={{this.field}}
        />
      </template>
    );
    await selectKit().expand();
    await selectKit().selectRowByName("monkey");

    assert.deepEqual(this.field.metadata.value, ["monkey"]);

    await selectKit().deselectItemByName("monkey");

    assert.strictEqual(this.field.metadata.value, undefined);
  });

  module("with the new select controls", function (nestedHooks) {
    nestedHooks.beforeEach(function () {
      this.siteSettings.enable_new_select_controls = true;
      this.field = new AutomationFabricators(getOwner(this)).field({
        component: "tags",
      });
    });

    test("set value with the new select controls", async function (assert) {
      await render(
        <template>
          <AutomationField
            @automation={{this.automation}}
            @field={{this.field}}
          />
        </template>
      );

      const tagChooser = dSelect(".tags-field .tag-chooser");
      await tagChooser.search("mon");
      await tagChooser.selectByName("monkey");

      assert.deepEqual(this.field.metadata.value, ["monkey"]);
    });

    test("empty tags with the new select controls", async function (assert) {
      await render(
        <template>
          <AutomationField
            @automation={{this.automation}}
            @field={{this.field}}
          />
        </template>
      );

      const tagChooser = dSelect(".tags-field .tag-chooser");
      await tagChooser.search("mon");
      await tagChooser.selectByName("monkey");

      assert.deepEqual(this.field.metadata.value, ["monkey"]);

      await tagChooser.close();
      assert
        .dom(".tags-field .d-select__chip[data-name='monkey']")
        .exists("shows the picked tag as a chip");
      await click(
        ".tags-field .d-select__chip[data-name='monkey'] .d-select__chip-remove"
      );

      assert.strictEqual(this.field.metadata.value, undefined);
    });
  });
});
