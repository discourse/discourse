import { tracked } from "@glimmer/tracking";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import GroupSelect from "discourse/plugins/discourse-workflows/admin/components/workflows/configurators/group-select";

class TestField {
  @tracked value;

  constructor(value) {
    this.value = value;
  }

  set(newValue) {
    this.value = newValue;
  }
}

module("Integration | Component | Workflows | GroupSelect", function (hooks) {
  setupRenderingTest(hooks);

  test("stores selected group names when configured as multiple", async function (assert) {
    this.field = new TestField([]);
    this.schema = {
      type_options: {
        load_options_method: "groups",
      },
      ui: {
        control: "group_select",
        multiple: true,
      },
      control_options: {
        filterable: true,
        name_property: "name",
        value_property: "name",
      },
    };
    this.nodeDefinition = {
      identifier: "action:send_personal_message",
      metadata: {
        groups: [
          { id: 1, name: "support" },
          { id: 2, name: "moderators" },
        ],
      },
    };

    await render(
      <template>
        <GroupSelect
          @field={{this.field}}
          @fieldName="recipient_group_names"
          @nodeDefinition={{this.nodeDefinition}}
          @schema={{this.schema}}
          @supportsExpression={{false}}
        />
      </template>
    );

    const chooser = selectKit(".group-chooser");
    await chooser.expand();
    await chooser.selectRowByValue("support");

    assert.deepEqual(this.field.value, ["support"]);

    await chooser.selectRowByValue("moderators");

    assert.deepEqual(this.field.value, ["support", "moderators"]);
  });
});
