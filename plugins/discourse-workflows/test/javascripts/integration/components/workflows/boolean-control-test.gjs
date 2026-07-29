import { click, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import BooleanControl from "discourse/plugins/discourse-workflows/admin/components/workflows/configurators/boolean-control";
import { WORKFLOW_VARIABLE_MIME } from "discourse/plugins/discourse-workflows/admin/lib/workflows/expression-context";

function dropVariable(selector, variable) {
  const dataTransfer = {
    types: [WORKFLOW_VARIABLE_MIME],
    getData: (type) =>
      type === WORKFLOW_VARIABLE_MIME ? JSON.stringify(variable) : "",
  };

  return triggerEvent(selector, "drop", { dataTransfer });
}

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

  test("dropping a variable on the plain toggle switches to expression mode", async function (assert) {
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

    await dropVariable(".workflows-property-engine__control-wrapper", {
      id: "$json.enabled",
    });

    assert.strictEqual(this.formApi.get("enabled"), "={{ $json.enabled }}");
    assert.dom(".form-kit__control-toggle").doesNotExist();
    assert.dom(".workflows-variable-input").exists();
  });

  test("dropping a variable is ignored when expressions are disabled", async function (assert) {
    this.setProperties({
      configuration: { enabled: false },
      formApi: null,
      schema: { type: "boolean", no_data_expression: true },
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

    await dropVariable(".workflows-property-engine__control-wrapper", {
      id: "$json.enabled",
    });

    assert.false(this.formApi.get("enabled"));
    assert.dom(".form-kit__control-toggle").exists();
  });
});
