import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import InputContext from "discourse/plugins/discourse-workflows/admin/components/workflows/context/input";

const EXPRESSION_CONTEXT = {
  environment: {
    $site_settings: { type: "object" },
    $vars: { type: "object" },
    $current_user: {
      type: "object",
      fields: { id: { type: "integer" }, username: { type: "string" } },
    },
    $execution: {
      type: "object",
      fields: {
        id: { type: "integer" },
        workflow_id: { type: "integer" },
        workflow_name: { type: "string" },
        resume_url: {
          type: "string",
          visible_if: {
            node_present: {
              type: "flow:wait",
              configuration: { resume: "webhook" },
            },
          },
        },
      },
    },
  },
  node_reference_shape: { item: { json: "object" }, context: "object" },
  item_prefix: "$json",
};

function makeNodes(...nodes) {
  return nodes;
}

module("Integration | Component | workflows/context/input", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    const service = this.owner.lookup("service:workflows-node-types");
    service.nodeTypes = [];
    service.credentialTypes = [];
    service.expressionContext = EXPRESSION_CONTEXT;
  });

  hooks.afterEach(function () {
    this.owner.lookup("service:workflows-node-types").clear();
  });

  test("renders environment fields", async function (assert) {
    const node = {
      clientId: "n1",
      type: "action:http_request",
      name: "HTTP",
    };
    const nodes = makeNodes(node);

    await render(
      <template>
        <InputContext
          @node={{node}}
          @nodes={{nodes}}
          @connections={{(Array)}}
          @nodeTypes={{(Array)}}
        />
      </template>
    );

    const sections = this.element.querySelectorAll(
      ".workflows-context-panel__section"
    );
    const envSection = sections[1];
    const fieldKeys = [
      ...envSection.querySelectorAll(".workflows-schema-field__key"),
    ].map((el) => el.textContent.trim());

    assert.true(fieldKeys.includes("site_settings"));
    assert.true(fieldKeys.includes("vars"));
    assert.true(fieldKeys.includes("current_user"));
    assert.true(fieldKeys.includes("execution"));
  });

  test("execution fields include resume_url when webhook wait node exists", async function (assert) {
    const waitNode = {
      clientId: "w1",
      type: "flow:wait",
      name: "Wait",
      configuration: { resume: "webhook" },
    };
    const actionNode = {
      clientId: "a1",
      type: "action:http_request",
      name: "HTTP",
    };
    const nodes = makeNodes(waitNode, actionNode);

    await render(
      <template>
        <InputContext
          @node={{actionNode}}
          @nodes={{nodes}}
          @connections={{(Array)}}
          @nodeTypes={{(Array)}}
        />
      </template>
    );

    const executionFields = this.element.querySelectorAll(
      ".workflows-schema-field"
    );
    const executionField = [...executionFields].find(
      (el) =>
        el.querySelector(".workflows-schema-field__key")?.textContent.trim() ===
        "execution"
    );

    await click(executionField.querySelector(".workflows-schema-field__row"));

    const allKeys = [
      ...this.element.querySelectorAll(".workflows-schema-field__key"),
    ].map((el) => el.textContent.trim());

    assert.true(allKeys.includes("resume_url"));
  });

  test("execution fields exclude resume_url when no webhook wait node", async function (assert) {
    const node = {
      clientId: "n1",
      type: "action:http_request",
      name: "HTTP",
    };
    const nodes = makeNodes(node);

    await render(
      <template>
        <InputContext
          @node={{node}}
          @nodes={{nodes}}
          @connections={{(Array)}}
          @nodeTypes={{(Array)}}
        />
      </template>
    );

    const executionFields = this.element.querySelectorAll(
      ".workflows-schema-field"
    );
    const executionField = [...executionFields].find(
      (el) =>
        el.querySelector(".workflows-schema-field__key")?.textContent.trim() ===
        "execution"
    );

    await click(executionField.querySelector(".workflows-schema-field__row"));

    const allKeys = [
      ...this.element.querySelectorAll(".workflows-schema-field__key"),
    ].map((el) => el.textContent.trim());

    assert.false(allKeys.includes("resume_url"));
  });

  test("renders ancestor nodes with $() expression format", async function (assert) {
    const triggerNode = {
      clientId: "t1",
      type: "trigger:webhook",
      name: "Webhook",
    };
    const step1 = {
      clientId: "s1",
      type: "action:http_request",
      name: "First Step",
      configuration: {
        output_fields: [{ key: "result", type: "string" }],
      },
    };
    const step2 = {
      clientId: "s2",
      type: "action:http_request",
      name: "Second Step",
      configuration: {
        output_fields: [{ key: "data", type: "object" }],
      },
    };
    const currentNode = {
      clientId: "c1",
      type: "action:http_request",
      name: "Current",
    };
    const nodes = makeNodes(triggerNode, step1, step2, currentNode);
    const connections = [
      { sourceClientId: "t1", targetClientId: "s1" },
      { sourceClientId: "s1", targetClientId: "s2" },
      { sourceClientId: "s2", targetClientId: "c1" },
    ];

    const webhookType = {
      identifier: "trigger:webhook",
      output_schema: { body: "object", method: "string" },
    };
    const nodeTypes = [webhookType];

    await render(
      <template>
        <InputContext
          @node={{currentNode}}
          @nodes={{nodes}}
          @connections={{connections}}
          @nodeTypes={{nodeTypes}}
        />
      </template>
    );

    const sectionTitles = [
      ...this.element.querySelectorAll(".workflows-context-panel__title"),
    ].map((el) => el.textContent.trim());

    assert.true(
      sectionTitles.some((t) => t.includes("First Step")),
      "shows ancestor node as section"
    );
  });

  test("environment fields match schema symbols", async function (assert) {
    const node = {
      clientId: "n1",
      type: "action:http_request",
      name: "HTTP",
    };

    await render(
      <template>
        <InputContext
          @node={{node}}
          @nodes={{Array node}}
          @connections={{(Array)}}
          @nodeTypes={{(Array)}}
        />
      </template>
    );

    const service = this.owner.lookup("service:workflows-node-types");
    const expectedSymbols = Object.keys(
      service.expressionContext.environment || {}
    );

    const sections = this.element.querySelectorAll(
      ".workflows-context-panel__section"
    );
    const envSection = sections[1];
    const fieldKeys = [
      ...envSection.querySelectorAll(
        ":scope > .workflows-schema-field-list > .workflows-schema-field"
      ),
    ].map((el) =>
      el.querySelector(".workflows-schema-field__key")?.textContent.trim()
    );

    expectedSymbols.forEach((symbol) => {
      const displayKey = symbol.replace(/^\$/, "");
      assert.true(
        fieldKeys.includes(displayKey),
        `expected environment field "${displayKey}" (from schema symbol "${symbol}") to be rendered`
      );
    });
  });
});
