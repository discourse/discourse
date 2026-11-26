import { tracked } from "@glimmer/tracking";
import { click, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import BooleanControl from "discourse/plugins/discourse-workflows/admin/components/workflows/configurators/boolean-control";
import { WORKFLOW_VARIABLE_MIME } from "discourse/plugins/discourse-workflows/admin/lib/workflows/expression-context";

const CONTROL_WRAPPER = ".workflows-property-engine__control-wrapper";

function variableTransfer(variable) {
  return {
    types: [WORKFLOW_VARIABLE_MIME],
    getData: (type) =>
      type === WORKFLOW_VARIABLE_MIME ? JSON.stringify(variable) : "",
  };
}

function dragVariableOver(variable) {
  return triggerEvent(CONTROL_WRAPPER, "dragover", {
    dataTransfer: variableTransfer(variable),
  });
}

function dropVariable(variable) {
  return triggerEvent(CONTROL_WRAPPER, "drop", {
    dataTransfer: variableTransfer(variable),
  });
}

module("Integration | Component | workflows boolean control", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    pretender.get("/admin/plugins/discourse-workflows/variables.json", () =>
      response(200, { variables: [] })
    );
  });

  test("renders toggle in plain mode", async function (assert) {
    const configuration = { enabled: false };
    const schema = { type: "boolean", ui: { expression: true } };
    const formApi = tracked(null);
    const registerApi = (api) => (formApi.value = api);

    await render(
      <template>
        <Form
          @data={{configuration}}
          @onRegisterApi={{registerApi}}
          as |form transientData|
        >
          <BooleanControl
            @configuration={{transientData}}
            @fieldName="enabled"
            @form={{form}}
            @formApi={{formApi.value}}
            @label="Enabled"
            @schema={{schema}}
          />
        </Form>
      </template>
    );

    assert.dom(".form-kit__control-toggle").exists();
    assert
      .dom(".form-kit__field-toggle .workflows-property-engine__mode-control")
      .exists("positions the switcher inside the toggle field");
  });

  test("switches to expression mode", async function (assert) {
    const configuration = { enabled: false };
    const schema = { type: "boolean", ui: { expression: true } };
    const formApi = tracked(null);
    const registerApi = (api) => (formApi.value = api);

    await render(
      <template>
        <Form
          @data={{configuration}}
          @onRegisterApi={{registerApi}}
          as |form transientData|
        >
          <BooleanControl
            @configuration={{transientData}}
            @fieldName="enabled"
            @form={{form}}
            @formApi={{formApi.value}}
            @label="Enabled"
            @schema={{schema}}
          />
        </Form>
      </template>
    );

    await click(
      '.workflows-property-engine__mode-control input[value="dynamic"]'
    );

    assert.dom(".form-kit__control-toggle").doesNotExist();
    assert.dom(".workflows-variable-input").exists();
    assert.strictEqual(formApi.value.get("enabled"), "=false");
  });

  test("switches true values to expression mode", async function (assert) {
    const configuration = { enabled: true };
    const schema = { type: "boolean", ui: { expression: true } };
    const formApi = tracked(null);
    const registerApi = (api) => (formApi.value = api);

    await render(
      <template>
        <Form
          @data={{configuration}}
          @onRegisterApi={{registerApi}}
          as |form transientData|
        >
          <BooleanControl
            @configuration={{transientData}}
            @fieldName="enabled"
            @form={{form}}
            @formApi={{formApi.value}}
            @label="Enabled"
            @schema={{schema}}
          />
        </Form>
      </template>
    );

    await click(
      '.workflows-property-engine__mode-control input[value="dynamic"]'
    );

    assert.dom(".workflows-variable-input").exists();
    assert.strictEqual(formApi.value.get("enabled"), "=true");
  });

  test("switches back to plain mode", async function (assert) {
    const configuration = { enabled: false };
    const schema = { type: "boolean", ui: { expression: true } };
    const formApi = tracked(null);
    const registerApi = (api) => (formApi.value = api);

    await render(
      <template>
        <Form
          @data={{configuration}}
          @onRegisterApi={{registerApi}}
          as |form transientData|
        >
          <BooleanControl
            @configuration={{transientData}}
            @fieldName="enabled"
            @form={{form}}
            @formApi={{formApi.value}}
            @label="Enabled"
            @schema={{schema}}
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
    assert.false(formApi.value.get("enabled"));
  });

  test("converts literal expressions back to plain booleans", async function (assert) {
    const configuration = { enabled: "={{ true }}" };
    const schema = { type: "boolean", ui: { expression: true } };
    const formApi = tracked(null);
    const registerApi = (api) => (formApi.value = api);

    await render(
      <template>
        <Form
          @data={{configuration}}
          @onRegisterApi={{registerApi}}
          as |form transientData|
        >
          <BooleanControl
            @configuration={{transientData}}
            @fieldName="enabled"
            @form={{form}}
            @formApi={{formApi.value}}
            @label="Enabled"
            @schema={{schema}}
          />
        </Form>
      </template>
    );

    await click(
      '.workflows-property-engine__mode-control input[value="plain"]'
    );

    assert.true(
      formApi.value.get("enabled"),
      "unwraps the literal instead of discarding it"
    );
  });

  test("renders in expression mode when value starts with =", async function (assert) {
    this.configuration = { enabled: "=true" };
    this.schema = { type: "boolean", ui: { expression: true } };

    await render(
      <template>
        <Form @data={{this.configuration}} as |form transientData|>
          <BooleanControl
            @configuration={{transientData}}
            @fieldName="enabled"
            @form={{form}}
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
    const configuration = { enabled: false };
    const schema = { type: "boolean", no_data_expression: true };
    const formApi = tracked(null);
    const registerApi = (api) => (formApi.value = api);

    await render(
      <template>
        <Form
          @data={{configuration}}
          @onRegisterApi={{registerApi}}
          as |form transientData|
        >
          <BooleanControl
            @configuration={{transientData}}
            @fieldName="enabled"
            @form={{form}}
            @formApi={{formApi.value}}
            @label="Enabled"
            @schema={{schema}}
          />
        </Form>
      </template>
    );

    assert.dom(".form-kit__control-toggle").exists();
    assert.dom(".workflows-property-engine__mode-control").doesNotExist();
    assert
      .dom(CONTROL_WRAPPER)
      .doesNotHaveAttribute(
        "data-supports-expression",
        "does not advertise itself as a drop target"
      );

    await dropVariable({ id: "enabled" });

    assert.false(
      formApi.value.get("enabled"),
      "ignores a dropped variable instead of storing an expression"
    );
    assert.dom(".form-kit__control-toggle").exists("stays a plain toggle");
  });

  test("dropping a variable on the plain toggle switches to expression mode", async function (assert) {
    const configuration = { enabled: false };
    const schema = { type: "boolean", ui: { expression: true } };
    const formApi = tracked(null);
    const registerApi = (api) => (formApi.value = api);

    await render(
      <template>
        <Form
          @data={{configuration}}
          @onRegisterApi={{registerApi}}
          as |form transientData|
        >
          <BooleanControl
            @configuration={{transientData}}
            @fieldName="enabled"
            @form={{form}}
            @formApi={{formApi.value}}
            @label="Enabled"
            @schema={{schema}}
          />
        </Form>
      </template>
    );

    await dragVariableOver({ id: "enabled" });

    assert
      .dom(CONTROL_WRAPPER)
      .hasClass("is-drag-over", "highlights the toggle as a drop target");

    await dropVariable({ id: "enabled" });

    assert.strictEqual(
      formApi.value.get("enabled"),
      "={{ $json.enabled }}",
      "stores the dropped variable as an expression, prefixed with the item path"
    );
    assert
      .dom(".form-kit__control-toggle")
      .doesNotExist("replaces the toggle rather than leaving a stale switch");
    assert.dom(".workflows-variable-input").exists();
  });
});
