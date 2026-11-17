import { render, settled, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import ExpressionInput from "discourse/plugins/discourse-workflows/admin/components/workflows/configurators/expression-input";
import WorkflowEditorSession from "discourse/plugins/discourse-workflows/admin/lib/workflows/editor-session";

module(
  "Integration | Component | Workflows | expression input",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      pretender.get("/admin/plugins/discourse-workflows/variables.json", () =>
        response(200, { variables: [] })
      );
    });

    test("refreshes the $json scope when output schemas load", async function (assert) {
      const trigger = {
        clientId: "trigger",
        name: "Trigger",
        type: "trigger:manual",
      };
      const action = {
        clientId: "action",
        name: "Action",
        type: "action:topic",
      };
      const session = new WorkflowEditorSession();
      session.setEditingContext(
        action,
        [trigger, action],
        [{ sourceClientId: "trigger", targetClientId: "action" }]
      );
      const field = { value: "={{ $json.post.raw }}", set() {} };

      await render(
        <template>
          <ExpressionInput @field={{field}} @session={{session}} />
        </template>
      );
      await waitFor(".cm-wf-reference-pill");

      assert.dom(".cm-wf-reference-pill").hasClass("--invalid");

      session.outputSchemas = {
        trigger: [
          {
            type: "object",
            properties: {
              post: { type: "object", properties: { raw: { type: "string" } } },
            },
          },
        ],
      };
      await settled();

      assert.dom(".cm-wf-reference-pill").hasClass("--value");
    });
  }
);
