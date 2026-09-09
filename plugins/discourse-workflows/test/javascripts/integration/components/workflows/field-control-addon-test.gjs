import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DButton from "discourse/ui-kit/d-button";
import Field from "discourse/plugins/discourse-workflows/admin/components/workflows/configurators/field";

class FieldControlAddonProbe extends Component {
  @action
  updateValue() {
    this.args.field.set("SELECT 2");
  }

  <template>
    <DButton
      class="btn-default field-control-addon-probe"
      @action={{this.updateValue}}
      @translatedLabel={{@field.value}}
    />
  </template>
}

module(
  "Integration | Component | Workflows | FieldControlAddon",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      withPluginApi((api) => {
        api.registerValueTransformer(
          "workflow-field-control",
          ({ value, context }) => {
            if (
              context.node?.type !== "action:sql" ||
              context.fieldName !== "query"
            ) {
              return value;
            }

            return {
              ...value,
              addons: [...(value.addons || []), FieldControlAddonProbe],
            };
          }
        );
      });
    });

    test("renders registered add-ons and updates through the FormKit field", async function (assert) {
      this.configuration = { query: "SELECT 1" };
      this.formApi = null;
      this.registerApi = (api) => {
        this.formApi = api;
      };

      await render(
        <template>
          <Form
            @data={{this.configuration}}
            @onRegisterApi={{this.registerApi}}
            as |form transientData|
          >
            <Field
              @configuration={{transientData}}
              @fieldName="query"
              @form={{form}}
              @label="Query"
              @node={{hash type="action:sql"}}
              @nodeParameters={{transientData}}
              @schema={{hash
                type="string"
                no_data_expression=true
                ui=(hash control="code")
              }}
            />
          </Form>
        </template>
      );

      assert
        .dom(".field-control-addon-probe")
        .hasText("SELECT 1", "the add-on receives the field value");

      await click(".field-control-addon-probe");

      assert.strictEqual(
        this.formApi.get("query"),
        "SELECT 2",
        "the add-on updates the FormKit field"
      );
    });
  }
);
