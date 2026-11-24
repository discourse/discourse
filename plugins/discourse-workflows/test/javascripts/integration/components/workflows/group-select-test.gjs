import { tracked } from "@glimmer/tracking";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DeprecationCounter from "discourse/tests/helpers/deprecation-counter";
import {
  disableRaiseOnDeprecation,
  enableRaiseOnDeprecation,
} from "discourse/tests/helpers/raise-on-deprecation";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import GroupSelect from "discourse/plugins/discourse-workflows/admin/components/workflows/configurators/group-select";

module("Integration | Component | Workflows | GroupSelect", function (hooks) {
  setupRenderingTest(hooks);

  test("stores selected group names when configured as multiple", async function (assert) {
    this.field = tracked([]);
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

  test("with the new select controls, the group chooser reports no legacy render", async function (assert) {
    disableRaiseOnDeprecation();
    const counter = sinon.stub(DeprecationCounter.prototype, "incrementCount");
    this.siteSettings.enable_new_select_controls = true;
    this.field = tracked([]);
    this.schema = {
      type_options: { load_options_method: "groups" },
      ui: { control: "group_select", multiple: true },
      control_options: { name_property: "name", value_property: "name" },
    };
    this.nodeDefinition = {
      identifier: "action:send_personal_message",
      metadata: { groups: [{ id: 1, name: "support" }] },
    };

    try {
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
    } finally {
      enableRaiseOnDeprecation();
    }

    assert.dom(".group-chooser").exists();
    assert.strictEqual(
      counter
        .getCalls()
        .filter(
          (call) =>
            call.args[0] === "discourse.select-kit-rollout.legacy-render"
        ).length,
      0,
      "the chooser stays on select-kit until its workflows wave"
    );
  });
});
