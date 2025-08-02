import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import AutomationField from "discourse/plugins/automation/admin/components/automation-field";
import AutomationFabricators from "discourse/plugins/automation/admin/lib/fabricators";

module("Integration | Component | da-groups-field", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.automation = new AutomationFabricators(getOwner(this)).automation();

    pretender.get("/groups/search.json", () => {
      return response([
        {
          id: 1,
          name: "cats",
          flair_url: "fa-bars",
          flair_bg_color: "CC000A",
          flair_color: "FFFFFA",
        },
        {
          id: 2,
          name: "dogs",
          flair_url: "fa-bars",
          flair_bg_color: "CC000A",
          flair_color: "FFFFFA",
        },
      ]);
    });
  });

  test("set value", async function (assert) {
    const self = this;

    this.field = new AutomationFabricators(getOwner(this)).field({
      component: "groups",
    });

    await render(
      <template>
        <AutomationField
          @automation={{self.automation}}
          @field={{self.field}}
        />
      </template>
    );

    await selectKit().expand();
    await selectKit().selectRowByValue(1);

    assert.deepEqual(this.field.metadata.value, [1]);
  });

  test("supports a maximum value", async function (assert) {
    const self = this;

    this.field = new AutomationFabricators(getOwner(this)).field({
      component: "groups",
      extra: { maximum: 1 },
    });

    await render(
      <template>
        <AutomationField
          @automation={{self.automation}}
          @field={{self.field}}
        />
      </template>
    );

    await selectKit().expand();
    await selectKit().selectRowByValue(1);

    assert.deepEqual(this.field.metadata.value, [1]);

    await selectKit().expand();
    await selectKit().selectRowByValue(2);

    assert.deepEqual(this.field.metadata.value, [2]);
  });

  test("empty", async function (assert) {
    const self = this;

    this.field = new AutomationFabricators(getOwner(this)).field({
      component: "groups",
    });

    await render(
      <template>
        <AutomationField
          @automation={{self.automation}}
          @field={{self.field}}
        />
      </template>
    );

    await selectKit().expand();
    await selectKit().selectRowByValue(1);

    assert.deepEqual(this.field.metadata.value, [1]);

    await selectKit().deselectItemByValue(1);

    assert.strictEqual(this.field.metadata.value, undefined);
  });
});
