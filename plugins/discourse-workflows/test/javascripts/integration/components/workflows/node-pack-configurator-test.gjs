import { click, render, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import NodeConfigurator from "discourse/plugins/discourse-workflows/admin/components/workflows/node/configurator";
import WorkflowEditorSession from "discourse/plugins/discourse-workflows/admin/lib/workflows/editor-session";
import packNodeTypes from "../../../fixtures/node-pack-node-types";

module(
  "Integration | Component | Workflows | Node | Configurator | NodePack",
  function (hooks) {
    setupRenderingTest(hooks, { stubRouter: true });

    test("renders pack metadata, credential label, properties, docs, and output schema", async function (assert) {
      pretender.get("/admin/plugins/discourse-workflows/credentials.json", () =>
        response({ credentials: [] })
      );
      const node = {
        clientId: "choice",
        name: "Route request",
        type: "action:example_pack.choice",
        typeVersion: "1.0",
        configuration: {},
      };
      const session = new WorkflowEditorSession({
        workflowId: 12,
        lastExecutionRunData: {},
      });
      this.owner.unregister("service:workflows-node-types");
      this.owner.register(
        "service:workflows-node-types",
        {
          credentialTypes: [],
          expressionContext: {},
          async load() {
            return packNodeTypes;
          },
        },
        { instantiate: false }
      );
      this.owner.unregister("service:modal");
      this.owner.register(
        "service:modal",
        {
          show: (_component, options) => {
            this.credentialModalModel = options.model;
          },
        },
        { instantiate: false }
      );
      this.set("closeModal", () => {});
      this.set("model", {
        inline: true,
        node,
        nodes: [node],
        connections: [],
        session,
        triggerType: null,
        async onSave() {},
      });

      await render(
        <template>
          <NodeConfigurator
            @closeModal={{this.closeModal}}
            @model={{this.model}}
          />
        </template>
      );
      await waitFor(".workflows-configurator-modal__pack-name");

      assert
        .dom(".workflows-configurator-modal__pack-name")
        .hasText("Example pack / Choose an option");
      assert
        .dom(".workflows-configurator-modal__pack-badge")
        .hasText("Imported · v1.0");
      assert
        .dom(".workflows-configurator-modal__docs-link")
        .hasAttribute("href", "https://example.com/docs/choice");
      assert
        .dom(".workflows-property-engine__label")
        .includesText("Example API token");
      assert
        .dom(".workflows-configurator-form .form-kit__container-title")
        .exists("scalar manifest properties render through the generic engine");
      assert
        .dom(".workflows-configurator-form")
        .includesText("Model")
        .includesText("State")
        .includesText("Options");
      assert
        .dom(".workflows-configurator-modal__column.--right")
        .includesText("choice")
        .includesText("confidence");

      await click(".workflows-property-engine__select-with-action .btn");
      assert.deepEqual(this.credentialModalModel.credentialSlot, {
        name: "auth",
        label: "Example API token",
        credential_types: ["bearer_token"],
      });
    });
  }
);
