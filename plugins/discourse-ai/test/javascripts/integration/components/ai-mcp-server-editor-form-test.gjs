import Service from "@ember/service";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";
import AiMcpServerEditorForm from "discourse/plugins/discourse-ai/discourse/components/ai-mcp-server-editor-form";

class ToastsStub extends Service {
  success() {}
}

module("Integration | Component | ai-mcp-server-editor-form", function (hooks) {
  setupRenderingTest(hooks, { stubRouter: true });

  hooks.beforeEach(function () {
    this.owner.unregister("service:toasts");
    this.owner.register("service:toasts", ToastsStub);

    const router = this.owner.lookup("service:router");
    router.replaceWith = async () => {};
    router.transitionTo = async () => {};

    this.secrets = [{ id: 1, name: "Microsoft token" }];
    this.mcpServers = { content: [] };
    this.savedPayload = null;
    this.model = {
      isNew: true,
      enabled: true,
      timeout_seconds: 30,
      oauth_status: "disconnected",
      oauth_client_metadata_url: "https://meta.example.com/discourse-ai.json",
      save: async (payload) => {
        this.savedPayload = payload;
        Object.assign(this.model, payload, { id: 42, isNew: false });
        return this.model;
      },
      destroyRecord: async () => {},
    };
  });

  test("switching auth mode keeps the entered URL and reveals credential fields", async function (assert) {
    await render(
      <template>
        <AiMcpServerEditorForm
          @model={{this.model}}
          @mcpServers={{this.mcpServers}}
          @secrets={{this.secrets}}
        />
      </template>
    );

    assert.false(
      formKit().hasField("max_calls_per_turn"),
      "does not render a max calls per turn field"
    );
    assert
      .dom(
        '.form-kit__field[data-name="timeout_seconds"] .fk-d-tooltip__trigger'
      )
      .exists("shows a tooltip for the timeout field");

    await formKit().field("name").fillIn("Microsoft");
    await formKit().field("description").fillIn("This is a description");
    await formKit().field("url").fillIn("https://learn.microsoft.com/api/mcp");

    await formKit().field("auth_type").select("header_secret");
    await settled();

    assert.dom(".ai-secret-selector").exists("shows credential selector");
    assert.form().field("url").hasValue("https://learn.microsoft.com/api/mcp");

    await formKit().submit();
    await settled();

    assert.strictEqual(
      this.savedPayload.url,
      "https://learn.microsoft.com/api/mcp",
      "submits the entered URL"
    );
    assert.strictEqual(
      this.savedPayload.auth_type,
      "header_secret",
      "submits the selected auth type"
    );
  });
});
