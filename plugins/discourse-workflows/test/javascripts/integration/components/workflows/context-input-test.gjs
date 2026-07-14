import { click, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import InputContext from "discourse/plugins/discourse-workflows/admin/components/workflows/context/input";
import WorkflowEditorSession from "discourse/plugins/discourse-workflows/admin/lib/workflows/editor-session";
import { WORKFLOW_VARIABLE_MIME } from "discourse/plugins/discourse-workflows/admin/lib/workflows/expression-context";

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
          display_options: {
            show: {
              node_present: [
                {
                  type: "flow:wait",
                  parameters: { resume: "webhook" },
                },
              ],
            },
          },
        },
        resumeFormUrl: {
          type: "string",
          display_options: {
            show: {
              node_present: [
                {
                  type: "action:form",
                  parameters: { page_type: "page" },
                },
              ],
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

module(
  "Integration | Component | Workflows | Context | Input",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      const service = this.owner.lookup("service:workflows-node-types");
      service.nodeTypes = [];
      service.credentialTypes = [];
      service.expressionContext = EXPRESSION_CONTEXT;
      this.session = new WorkflowEditorSession({ lastExecutionRunData: {} });
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
            @session={{this.session}}
          />
        </template>
      );

      const sections = this.element.querySelectorAll(
        ".workflows-context-panel__section"
      );
      const envSection = sections[0];
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
            @session={{this.session}}
          />
        </template>
      );

      const executionFields = this.element.querySelectorAll(
        ".workflows-schema-field"
      );
      const executionField = [...executionFields].find(
        (el) =>
          el
            .querySelector(".workflows-schema-field__key")
            ?.textContent.trim() === "execution"
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
            @session={{this.session}}
          />
        </template>
      );

      const executionFields = this.element.querySelectorAll(
        ".workflows-schema-field"
      );
      const executionField = [...executionFields].find(
        (el) =>
          el
            .querySelector(".workflows-schema-field__key")
            ?.textContent.trim() === "execution"
      );

      await click(executionField.querySelector(".workflows-schema-field__row"));

      const allKeys = [
        ...this.element.querySelectorAll(".workflows-schema-field__key"),
      ].map((el) => el.textContent.trim());

      assert.false(allKeys.includes("resume_url"));
    });

    test("execution fields include resumeFormUrl when a form page node exists", async function (assert) {
      const formNode = {
        clientId: "f1",
        type: "action:form",
        name: "Form",
        configuration: { page_type: "page" },
      };
      const actionNode = {
        clientId: "a1",
        type: "action:http_request",
        name: "HTTP",
      };
      const nodes = makeNodes(formNode, actionNode);

      await render(
        <template>
          <InputContext
            @node={{actionNode}}
            @nodes={{nodes}}
            @connections={{(Array)}}
            @nodeTypes={{(Array)}}
            @session={{this.session}}
          />
        </template>
      );

      const executionFields = this.element.querySelectorAll(
        ".workflows-schema-field"
      );
      const executionField = [...executionFields].find(
        (el) =>
          el
            .querySelector(".workflows-schema-field__key")
            ?.textContent.trim() === "execution"
      );

      await click(executionField.querySelector(".workflows-schema-field__row"));

      const allKeys = [
        ...this.element.querySelectorAll(".workflows-schema-field__key"),
      ].map((el) => el.textContent.trim());

      assert.true(allKeys.includes("resumeFormUrl"));
    });

    test("uses previous node name as the input heading", async function (assert) {
      const triggerNode = {
        clientId: "t1",
        type: "trigger:webhook",
        name: "Webhook",
      };
      const step1 = {
        clientId: "s1",
        type: "action:http_request",
        name: "First Step",
      };
      const currentNode = {
        clientId: "c1",
        type: "action:http_request",
        name: "Current",
      };
      const nodes = makeNodes(triggerNode, step1, currentNode);
      const connections = [
        { sourceClientId: "t1", targetClientId: "s1" },
        { sourceClientId: "s1", targetClientId: "c1" },
      ];
      this.session.lastExecutionRunData = {
        "First Step": [
          {
            status: "success",
            outputs: [
              {
                index: 0,
                items: [{ json: { result: "ok" } }],
                item_count: 1,
              },
            ],
          },
        ],
      };

      await render(
        <template>
          <InputContext
            @node={{currentNode}}
            @nodes={{nodes}}
            @connections={{connections}}
            @nodeTypes={{(Array)}}
            @session={{this.session}}
          />
        </template>
      );

      const firstTitle = this.element
        .querySelector(
          ".workflows-context-panel__section .workflows-context-panel__title"
        )
        .textContent.trim();
      const keys = [
        ...this.element.querySelectorAll(".workflows-schema-field__key-title"),
      ].map((el) => el.textContent.trim());

      assert.true(firstTitle.includes("First Step"));
      assert.true(firstTitle.includes("1 item"));
      assert.dom(".workflows-context-panel__item-title").doesNotExist();
      assert.true(keys.includes("result"));
      assert.dom(".workflows-context-panel__empty").doesNotExist();
    });

    test("shows an empty input state when the input has no JSON fields", async function (assert) {
      const previousNode = {
        clientId: "previous-1",
        type: "action:http_request",
        name: "Previous",
      };
      const currentNode = {
        clientId: "current-1",
        type: "action:http_request",
        name: "Current",
      };
      const nodes = makeNodes(previousNode, currentNode);
      const connections = [
        { sourceClientId: "previous-1", targetClientId: "current-1" },
      ];
      this.session.lastExecutionRunData = {
        Current: [
          {
            status: "success",
            inputs: [
              {
                index: 0,
                items: [{ json: {} }],
                item_count: 1,
                source: { node_name: "Previous", output_index: 0 },
              },
            ],
          },
        ],
      };

      await render(
        <template>
          <InputContext
            @node={{currentNode}}
            @nodes={{nodes}}
            @connections={{connections}}
            @nodeTypes={{(Array)}}
            @session={{this.session}}
          />
        </template>
      );

      assert.dom(".workflows-context-panel__item-title").doesNotExist();
      assert.dom(".workflows-context-panel__title-meta").hasText("1 item");
      assert.dom(".workflows-context-panel__empty").hasText("No input fields");
    });

    test("shows an empty input state before the input has run", async function (assert) {
      const previousNode = {
        clientId: "previous-1",
        type: "action:http_request",
        name: "Previous",
      };
      const currentNode = {
        clientId: "current-1",
        type: "action:http_request",
        name: "Current",
      };
      const nodes = makeNodes(previousNode, currentNode);
      const connections = [
        { sourceClientId: "previous-1", targetClientId: "current-1" },
      ];

      await render(
        <template>
          <InputContext
            @node={{currentNode}}
            @nodes={{nodes}}
            @connections={{connections}}
            @nodeTypes={{(Array)}}
            @session={{this.session}}
          />
        </template>
      );

      assert
        .dom(".workflows-context-panel__empty")
        .hasText("No input data yet. It will appear after the first run.");
    });

    test("renders each direct input source for multi-input nodes", async function (assert) {
      const leftNode = {
        clientId: "left-1",
        type: "action:http_request",
        name: "Left",
      };
      const rightNode = {
        clientId: "right-1",
        type: "action:http_request",
        name: "Right",
      };
      const currentNode = {
        clientId: "merge-1",
        type: "action:merge",
        name: "Merge",
      };
      const nodes = makeNodes(leftNode, rightNode, currentNode);
      const connections = [
        {
          sourceClientId: "right-1",
          targetClientId: "merge-1",
          targetInputIndex: 1,
        },
        {
          sourceClientId: "left-1",
          targetClientId: "merge-1",
          targetInputIndex: 0,
        },
      ];
      this.session.lastExecutionRunData = {
        Left: [
          {
            status: "success",
            outputs: [
              { index: 0, items: [{ json: { left: true } }], item_count: 1 },
            ],
          },
        ],
        Right: [
          {
            status: "success",
            outputs: [
              { index: 0, items: [{ json: { right: true } }], item_count: 1 },
            ],
          },
        ],
        Merge: [
          {
            status: "success",
            inputs: [
              {
                index: 0,
                items: [{ json: { left: true } }],
                item_count: 1,
                source: { node_name: "Left", output_index: 0 },
              },
              {
                index: 1,
                items: [{ json: { right: true } }],
                item_count: 1,
                source: { node_name: "Right", output_index: 0 },
              },
            ],
          },
        ],
      };

      await render(
        <template>
          <InputContext
            @node={{currentNode}}
            @nodes={{nodes}}
            @connections={{connections}}
            @nodeTypes={{(Array)}}
            @session={{this.session}}
          />
        </template>
      );

      const sectionTitles = [
        ...this.element.querySelectorAll(".workflows-context-panel__title"),
      ].map((el) => el.textContent.trim());
      const keys = [
        ...this.element.querySelectorAll(".workflows-schema-field__key-title"),
      ].map((el) => el.textContent.trim());

      assert.true(sectionTitles[0].includes("Left"));
      assert.true(sectionTitles[0].includes("Input 1"));
      assert.true(sectionTitles[0].includes("1 item"));
      assert.true(sectionTitles[1].includes("Right"));
      assert.true(sectionTitles[1].includes("Input 2"));
      assert.true(sectionTitles[1].includes("1 item"));
      assert.true(keys.includes("left"));
      assert.true(keys.includes("right"));

      const fieldRows = [
        ...this.element.querySelectorAll(".workflows-schema-field__key"),
      ];
      const leftField = fieldRows.find(
        (el) => el.textContent.trim() === "left"
      );
      const rightField = fieldRows.find(
        (el) => el.textContent.trim() === "right"
      );
      const dragged = {};
      const dataTransfer = {
        setData(type, value) {
          dragged[type] = value;
        },
      };

      await triggerEvent(leftField, "dragstart", { dataTransfer });
      assert.strictEqual(
        JSON.parse(dragged[WORKFLOW_VARIABLE_MIME]).id,
        "$json.left"
      );

      await triggerEvent(rightField, "dragstart", { dataTransfer });
      assert.strictEqual(
        JSON.parse(dragged[WORKFLOW_VARIABLE_MIME]).id,
        '$("Right").all(0)[$itemIndex].json.right'
      );
    });

    test("uses current node recorded input when previous node output differs", async function (assert) {
      const logNode = {
        clientId: "log-1",
        type: "action:log",
        name: "Log",
      };
      const currentNode = {
        clientId: "current-1",
        type: "action:http_request",
        name: "Current",
      };
      const nodes = makeNodes(logNode, currentNode);
      const connections = [
        { sourceClientId: "log-1", targetClientId: "current-1" },
      ];
      this.session.lastExecutionRunData = {
        Log: [
          {
            status: "success",
            outputs: [{ index: 0, items: [], item_count: 0 }],
          },
        ],
        Current: [
          {
            status: "success",
            inputs: [
              {
                index: 0,
                items: [{ json: { topic: { id: 1, title: "Runtime topic" } } }],
                item_count: 1,
                source: { node_name: "Log", output_index: 0 },
              },
            ],
          },
        ],
      };

      await render(
        <template>
          <InputContext
            @node={{currentNode}}
            @nodes={{nodes}}
            @connections={{connections}}
            @nodeTypes={{(Array)}}
            @session={{this.session}}
          />
        </template>
      );

      const firstTitle = this.element
        .querySelector(
          ".workflows-context-panel__section .workflows-context-panel__title"
        )
        .textContent.trim();
      const keys = [
        ...this.element.querySelectorAll(".workflows-schema-field__key-title"),
      ].map((el) => el.textContent.trim());

      assert.true(firstTitle.includes("Log"));
      assert.true(firstTitle.includes("1 item"));
      assert.dom(".workflows-context-panel__item-title").doesNotExist();
      assert.true(keys.includes("topic"));
    });

    test("shows no input data when recorded input source is stale", async function (assert) {
      const postMovedNode = {
        clientId: "post-moved",
        type: "trigger:post_moved",
        name: "Post moved",
      };
      const logNode = {
        clientId: "log",
        type: "action:log",
        name: "Log",
      };
      const nodes = makeNodes(postMovedNode, logNode);
      const connections = [
        { sourceClientId: "post-moved", targetClientId: "log" },
      ];
      this.session.lastExecutionRunData = {
        "Post moved": [
          {
            node_id: "post-moved",
            node_type: "trigger:post_moved",
            status: "success",
            outputs: [
              {
                index: 0,
                items: [{ json: { post: { id: 1 } } }],
                item_count: 1,
              },
            ],
          },
        ],
        Log: [
          {
            node_id: "log",
            node_type: "action:log",
            status: "success",
            inputs: [
              {
                index: 0,
                items: [{ json: { reviewable: { id: 1 } } }],
                item_count: 1,
                source: { node_name: "Approved reviewable", output_index: 0 },
              },
            ],
          },
        ],
      };

      await render(
        <template>
          <InputContext
            @node={{logNode}}
            @nodes={{nodes}}
            @connections={{connections}}
            @nodeTypes={{(Array)}}
            @session={{this.session}}
          />
        </template>
      );

      const firstTitle = this.element
        .querySelector(
          ".workflows-context-panel__section .workflows-context-panel__title"
        )
        .textContent.trim();
      const keys = [
        ...this.element.querySelectorAll(".workflows-schema-field__key-title"),
      ].map((el) => el.textContent.trim());

      assert.true(firstTitle.includes("Post moved"));
      assert.false(firstTitle.includes("1 item"));
      assert.false(keys.includes("post"));
      assert.false(keys.includes("reviewable"));
      assert
        .dom(".workflows-context-panel__empty")
        .hasText("No input data yet. It will appear after the first run.");
    });

    test("hides the input section when there is no previous node", async function (assert) {
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
            @session={{this.session}}
          />
        </template>
      );

      const firstTitle = this.element
        .querySelector(
          ".workflows-context-panel__section .workflows-context-panel__title"
        )
        .textContent.trim();

      assert.strictEqual(
        firstTitle,
        "Environment",
        "first section is Environment, input section is hidden"
      );
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
      };
      const step2 = {
        clientId: "s2",
        type: "action:http_request",
        name: "Second Step",
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

      const nodeTypes = [];
      this.session.lastExecutionRunData = {
        "First Step": [
          {
            status: "success",
            outputs: [
              {
                index: 0,
                items: [{ json: { result: "ok" } }],
                item_count: 1,
              },
            ],
          },
        ],
        "Second Step": [
          {
            status: "success",
            outputs: [
              {
                index: 0,
                items: [{ json: { data: { id: 1 } } }],
                item_count: 1,
              },
            ],
          },
        ],
      };

      await render(
        <template>
          <InputContext
            @node={{currentNode}}
            @nodes={{nodes}}
            @connections={{connections}}
            @nodeTypes={{nodeTypes}}
            @session={{this.session}}
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

      const resultField = [
        ...this.element.querySelectorAll(".workflows-schema-field__key"),
      ].find((el) => el.textContent.trim() === "result");
      const dragged = {};
      const dataTransfer = {
        setData(type, value) {
          dragged[type] = value;
        },
      };

      await triggerEvent(resultField, "dragstart", { dataTransfer });

      assert.strictEqual(
        JSON.parse(dragged[WORKFLOW_VARIABLE_MIME]).id,
        '$("First Step").first().json.result'
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
            @session={{this.session}}
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
      const envSection = sections[0];
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
  }
);
