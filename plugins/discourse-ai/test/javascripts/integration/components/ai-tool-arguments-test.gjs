import Service from "@ember/service";
import { fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AiToolArguments from "discourse/plugins/discourse-ai/admin/components/workflows/ai-tool-arguments";

class WorkflowNodeTypesStub extends Service {
  async loadNodeParameterOptions() {
    return [
      {
        name: "config",
        type: "object",
        required: true,
        enum: [{ mode: "fast" }, { mode: "safe" }],
      },
    ];
  }
}

// The workflow plugin supplies this adapter. Structured enums must use the
// JSON editor instead of select options with colliding string values.
const ArgumentField = <template>
  <@form.Field
    @name={{@fieldName}}
    @onSet={{@onSet}}
    @title={{@label}}
    @type="select"
    as |field|
  >
    <field.Control as |control|>
      {{#each @schema.options as |option|}}
        <control.Option
          @value={{option.value}}
        >{{option.label}}</control.Option>
      {{/each}}
    </field.Control>
  </@form.Field>
</template>;

module("Integration | Component | AiToolArguments", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.owner.register("service:workflows-node-types", WorkflowNodeTypesStub);
    this.configuration = { tool_ref: "custom:1", arguments: {} };
    this.nodeDefinition = { name: "action:ai_tool", version: "1.0" };
  });

  test("edits structured enum arguments as JSON without changing the selected member", async function (assert) {
    await render(
      <template>
        <Form @data={{this.configuration}} as |form transientData|>
          <AiToolArguments
            @configuration={{transientData}}
            @Field={{ArgumentField}}
            @fieldName="arguments"
            @form={{form}}
            @label="Arguments"
            @nodeDefinition={{this.nodeDefinition}}
            @nodeParameters={{transientData}}
          />
          <output>{{transientData.arguments.config.mode}}</output>
        </Form>
      </template>
    );

    assert.dom("select").doesNotExist();
    assert.dom("textarea").exists();
    await fillIn("textarea", JSON.stringify({ config: { mode: "safe" } }));
    assert.dom("output").hasText("safe");
  });
});
