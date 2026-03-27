import { click, fillIn, findAll, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import PropertyEngineConfigurator from "discourse/plugins/discourse-workflows/admin/components/workflows/configurators/property-engine";

module("Integration | Component | workflows property engine", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    pretender.get("/svg-sprite/picker-search", () =>
      response(200, [{ id: "bolt", name: "bolt" }])
    );
  });

  test("preserves focus for scalar fields while typing", async function (assert) {
    this.setProperties({
      configuration: { title: "" },
      nodeType: "action:create_topic",
      schema: {
        title: {
          type: "string",
          required: true,
        },
      },
    });

    await render(
      <template>
        <Form @data={{this.configuration}} as |form transientData|>
          <PropertyEngineConfigurator
            @form={{form}}
            @configuration={{transientData}}
            @nodeType={{this.nodeType}}
            @schema={{this.schema}}
          />
        </Form>
      </template>
    );

    await fillIn("input", "Hello");

    assert.dom("input").hasValue("Hello");
    assert.dom("input").isFocused();
  });

  test("preserves focus for collection fields while typing", async function (assert) {
    this.setProperties({
      configuration: {
        headers: [{ key: "", value: "" }],
      },
      nodeType: "action:http_request",
      schema: {
        headers: {
          type: "collection",
          item_schema: {
            key: {
              type: "string",
              required: true,
            },
            value: {
              type: "string",
              required: true,
            },
          },
        },
      },
    });

    await render(
      <template>
        <Form @data={{this.configuration}} as |form transientData|>
          <PropertyEngineConfigurator
            @form={{form}}
            @configuration={{transientData}}
            @nodeType={{this.nodeType}}
            @schema={{this.schema}}
          />
        </Form>
      </template>
    );

    let [keyInput] = findAll(
      ".workflows-property-engine__collection-row input"
    );

    await fillIn(keyInput, "Authorization");

    [keyInput] = findAll(".workflows-property-engine__collection-row input");

    assert.strictEqual(keyInput.value, "Authorization");
    assert.strictEqual(document.activeElement, keyInput);
  });

  test("renders condition builder controls inside the property engine", async function (assert) {
    this.setProperties({
      configuration: {
        conditions: [],
      },
      formApi: null,
      node: {
        clientId: "branch",
        type: "condition:if",
      },
      nodes: [
        {
          clientId: "trigger",
          type: "trigger:manual",
        },
        {
          clientId: "branch",
          type: "condition:if",
        },
      ],
      connections: [
        {
          sourceClientId: "trigger",
          targetClientId: "branch",
        },
      ],
      nodeTypes: [
        {
          identifier: "trigger:manual",
          output_schema: {
            status: "string",
          },
        },
      ],
      nodeType: "condition:if",
      schema: {
        conditions: {
          type: "array",
          ui: {
            control: "condition_builder",
          },
        },
      },
      registerApi: (api) => {
        this.set("formApi", api);
      },
    });

    await render(
      <template>
        <Form
          @data={{this.configuration}}
          @onRegisterApi={{this.registerApi}}
          as |form transientData|
        >
          <PropertyEngineConfigurator
            @form={{form}}
            @formApi={{this.formApi}}
            @configuration={{transientData}}
            @connections={{this.connections}}
            @node={{this.node}}
            @nodes={{this.nodes}}
            @nodeType={{this.nodeType}}
            @nodeTypes={{this.nodeTypes}}
            @schema={{this.schema}}
          />
        </Form>
      </template>
    );

    await click(".btn-default.btn-small");

    const conditions = this.formApi.get("conditions");
    assert.strictEqual(conditions.length, 1);
    assert.dom(".workflows-configurator-if__row").exists();
    assert
      .dom(".workflows-configurator-if__row option[value='status']")
      .exists();
  });

  test("renders webhook URL previews from schema controls", async function (assert) {
    this.setProperties({
      configuration: { path: "my-hook" },
      nodeType: "trigger:webhook",
      schema: {
        path: {
          type: "string",
        },
        url_preview: {
          type: "custom",
          ui: {
            control: "webhook_url_preview",
          },
        },
      },
    });

    await render(
      <template>
        <Form @data={{this.configuration}} as |form transientData|>
          <PropertyEngineConfigurator
            @form={{form}}
            @configuration={{transientData}}
            @nodeType={{this.nodeType}}
            @schema={{this.schema}}
          />
        </Form>
      </template>
    );

    assert
      .dom(".workflows-url-preview code")
      .includesText("/workflows/webhooks/my-hook");
  });

  test("renders icon fields with the form-kit icon control", async function (assert) {
    this.setProperties({
      configuration: { icon: "gear" },
      formApi: null,
      nodeType: "trigger:topic_admin_button",
      schema: {
        icon: {
          type: "icon",
        },
      },
      registerApi: (api) => {
        this.set("formApi", api);
      },
    });

    await render(
      <template>
        <Form
          @data={{this.configuration}}
          @onRegisterApi={{this.registerApi}}
          as |form transientData|
        >
          <PropertyEngineConfigurator
            @form={{form}}
            @formApi={{this.formApi}}
            @configuration={{transientData}}
            @nodeType={{this.nodeType}}
            @schema={{this.schema}}
          />
        </Form>
      </template>
    );

    assert.dom(".form-kit__control-icon").exists();
    assert.strictEqual(
      selectKit(".form-kit__control-icon").header().value(),
      "gear"
    );

    await selectKit(".form-kit__control-icon").expand();
    await selectKit(".form-kit__control-icon").selectRowByValue("bolt");

    assert.strictEqual(
      selectKit(".form-kit__control-icon").header().value(),
      "bolt"
    );

    await click(".workflows-property-engine__mode-trigger");

    assert.strictEqual(this.formApi.get("icon"), "=bolt");
    assert.dom(".workflows-variable-input").exists();
  });

  test("select fields render with correct initial value", async function (assert) {
    this.setProperties({
      configuration: { combinator: "or" },
      nodeType: "condition:if",
      schema: {
        combinator: {
          type: "options",
          options: ["and", "or"],
          default: "and",
          ui: {
            expression: false,
          },
        },
      },
    });

    await render(
      <template>
        <Form @data={{this.configuration}} as |form transientData|>
          <PropertyEngineConfigurator
            @form={{form}}
            @configuration={{transientData}}
            @nodeType={{this.nodeType}}
            @schema={{this.schema}}
          />
        </Form>
      </template>
    );

    assert.strictEqual(
      document.querySelector(".form-kit__control-custom select").value,
      "or"
    );
  });

  test("renders combo boxes from metadata and applies option patches", async function (assert) {
    this.setProperties({
      configuration: { agent_id: 2, agent_name: "" },
      formApi: null,
      nodeType: "action:ai_agent",
      nodeTypes: [
        {
          identifier: "action:ai_agent",
          metadata: {
            agents: [
              { id: 1, name: "Support Bot" },
              { id: 2, name: "Helper Bot" },
            ],
            i18n_prefix: "discourse_ai.discourse_workflows",
          },
        },
      ],
      schema: {
        agent_id: {
          type: "integer",
          required: true,
          ui: {
            control: "combo_box",
            expression: false,
            filterable: true,
            name_property: "name",
            none: "discourse_ai.discourse_workflows.ai_agent.select_agent",
            options_source: "agents",
            patch_from_option: {
              agent_name: "name",
            },
            value_property: "id",
          },
        },
      },
      registerApi: (api) => {
        this.set("formApi", api);
      },
    });

    await render(
      <template>
        <Form
          @data={{this.configuration}}
          @onRegisterApi={{this.registerApi}}
          as |form transientData|
        >
          <PropertyEngineConfigurator
            @form={{form}}
            @formApi={{this.formApi}}
            @configuration={{transientData}}
            @nodeType={{this.nodeType}}
            @nodeTypes={{this.nodeTypes}}
            @schema={{this.schema}}
          />
        </Form>
      </template>
    );

    const selector = selectKit(".combo-box");
    assert.strictEqual(selector.header().value(), "2");
    assert.strictEqual(selector.header().label(), "Helper Bot");

    await selector.expand();
    await selector.selectRowByValue("1");

    assert.strictEqual(String(this.formApi.get("agent_id")), "1");
    assert.strictEqual(this.formApi.get("agent_name"), "Support Bot");
  });
});
