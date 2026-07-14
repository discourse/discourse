import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import BooleanControl from "discourse/plugins/discourse-workflows/admin/components/workflows/configurators/boolean-control";

module("Integration | Component | workflows boolean control", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    pretender.get("/admin/plugins/discourse-workflows/variables.json", () =>
      response(200, { variables: [] })
    );
  });

  test("renders toggle in plain mode", async function (assert) {
    this.setProperties({
      configuration: { enabled: false },
      formApi: null,
      schema: { type: "boolean", ui: { expression: true } },
      registerApi: (api) => this.set("formApi", api),
    });

    await render(
      <template>
        <Form
          @data={{this.configuration}}
          @onRegisterApi={{this.registerApi}}
          as |form transientData|
        >
          <BooleanControl
            @form={{form}}
            @formApi={{this.formApi}}
            @configuration={{transientData}}
            @fieldName="enabled"
            @label="Enabled"
            @schema={{this.schema}}
          />
        </Form>
      </template>
    );

    assert.dom(".form-kit__control-toggle").exists();
    assert.dom(".workflows-property-engine__mode-control").exists();
  });

  test("switches to expression mode", async function (assert) {
    this.setProperties({
      configuration: { enabled: false },
      formApi: null,
      schema: { type: "boolean", ui: { expression: true } },
      registerApi: (api) => this.set("formApi", api),
    });

    await render(
      <template>
        <Form
          @data={{this.configuration}}
          @onRegisterApi={{this.registerApi}}
          as |form transientData|
        >
          <BooleanControl
            @form={{form}}
            @formApi={{this.formApi}}
            @configuration={{transientData}}
            @fieldName="enabled"
            @label="Enabled"
            @schema={{this.schema}}
          />
        </Form>
      </template>
    );

    await click(
      '.workflows-property-engine__mode-control input[value="dynamic"]'
    );

    assert.dom(".form-kit__control-toggle").doesNotExist();
    assert.dom(".workflows-variable-input").exists();
    assert.strictEqual(this.formApi.get("enabled"), "=false");
  });

  test("switches true values to expression mode", async function (assert) {
    this.setProperties({
      configuration: { enabled: true },
      formApi: null,
      schema: { type: "boolean", ui: { expression: true } },
      registerApi: (api) => this.set("formApi", api),
    });

    await render(
      <template>
        <Form
          @data={{this.configuration}}
          @onRegisterApi={{this.registerApi}}
          as |form transientData|
        >
          <BooleanControl
            @form={{form}}
            @formApi={{this.formApi}}
            @configuration={{transientData}}
            @fieldName="enabled"
            @label="Enabled"
            @schema={{this.schema}}
          />
        </Form>
      </template>
    );

    await click(
      '.workflows-property-engine__mode-control input[value="dynamic"]'
    );

    assert.dom(".workflows-variable-input").exists();
    assert.strictEqual(this.formApi.get("enabled"), "=true");
  });

  test("switches back to plain mode", async function (assert) {
    this.setProperties({
      configuration: { enabled: false },
      formApi: null,
      schema: { type: "boolean", ui: { expression: true } },
      registerApi: (api) => this.set("formApi", api),
    });

    await render(
      <template>
        <Form
          @data={{this.configuration}}
          @onRegisterApi={{this.registerApi}}
          as |form transientData|
        >
          <BooleanControl
            @form={{form}}
            @formApi={{this.formApi}}
            @configuration={{transientData}}
            @fieldName="enabled"
            @label="Enabled"
            @schema={{this.schema}}
          />
        </Form>
      </template>
    );

    await click(
      '.workflows-property-engine__mode-control input[value="dynamic"]'
    );
    await click(
      '.workflows-property-engine__mode-control input[value="plain"]'
    );

    assert.dom(".form-kit__control-toggle").exists();
    assert.dom(".workflows-variable-input").doesNotExist();
    assert.false(this.formApi.get("enabled"));
  });

  test("renders in expression mode when value starts with =", async function (assert) {
    this.setProperties({
      configuration: { enabled: "=true" },
      schema: { type: "boolean", ui: { expression: true } },
    });

    await render(
      <template>
        <Form @data={{this.configuration}} as |form transientData|>
          <BooleanControl
            @form={{form}}
            @configuration={{transientData}}
            @fieldName="enabled"
            @label="Enabled"
            @schema={{this.schema}}
          />
        </Form>
      </template>
    );

    assert.dom(".form-kit__control-toggle").doesNotExist();
    assert.dom(".workflows-variable-input").exists();
  });

  test("renders plain toggle without mode control when expressions disabled", async function (assert) {
    this.setProperties({
      configuration: { enabled: false },
      schema: { type: "boolean", no_data_expression: true },
    });

    await render(
      <template>
        <Form @data={{this.configuration}} as |form transientData|>
          <BooleanControl
            @form={{form}}
            @configuration={{transientData}}
            @fieldName="enabled"
            @label="Enabled"
            @schema={{this.schema}}
          />
        </Form>
      </template>
    );

    assert.dom(".form-kit__control-toggle").exists();
    assert.dom(".workflows-property-engine__mode-control").doesNotExist();
  });
});
