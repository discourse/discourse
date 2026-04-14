import Service from "@ember/service";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AiToolListEditor from "discourse/plugins/discourse-ai/discourse/components/ai-tool-list-editor";

class AdminPluginNavManagerStub extends Service {
  currentPlugin = { name: "discourse-ai" };
}

class ModalStub extends Service {
  shownComponent = null;
  shownOptions = null;

  show(component, options) {
    this.shownComponent = component;
    this.shownOptions = options;
  }
}

module("Integration | Component | ai-tool-list-editor", function (hooks) {
  setupRenderingTest(hooks, { stubRouter: true });

  hooks.beforeEach(function () {
    this.owner.unregister("service:admin-plugin-nav-manager");
    this.owner.register(
      "service:admin-plugin-nav-manager",
      AdminPluginNavManagerStub
    );

    this.owner.unregister("service:modal");
    this.owner.register("service:modal", ModalStub);

    this.modal = this.owner.lookup("service:modal");
    this.tools = {
      content: [],
      resultSetMeta: { presets: [] },
    };
    this.mcpServers = {
      content: [
        {
          id: 1,
          name: "microsoft mcp",
          description: "Microsoft Learn tools",
          tool_count: 1,
          last_health_status: "healthy",
          tools: [
            {
              name: "microsoft_docs_search",
              title: "Microsoft Docs Search",
              description: "Search official Microsoft documentation.",
              parameters: [
                {
                  name: "query",
                  type: "string",
                  description: "Search query",
                  required: true,
                },
              ],
            },
          ],
        },
      ],
    };
  });

  test("clicking the MCP tool count opens the tools modal with tool details", async function (assert) {
    await render(
      <template>
        <AiToolListEditor
          @tools={{this.tools}}
          @mcpServers={{this.mcpServers}}
        />
      </template>
    );

    assert
      .dom(".ai-tool-list__mcp-tools-button")
      .hasText("1 tool", "renders the tool count as a button");

    await click(".ai-tool-list__mcp-tools-button");

    assert.strictEqual(
      this.modal.shownOptions.model.serverName,
      "microsoft mcp",
      "passes the server name to the modal"
    );
    assert.strictEqual(
      this.modal.shownOptions.model.tools[0].title,
      "Microsoft Docs Search",
      "passes tool metadata to the modal"
    );
    assert.strictEqual(
      this.modal.shownOptions.model.tools[0].parameters[0].name,
      "query",
      "passes tool parameter metadata to the modal"
    );
  });
});
