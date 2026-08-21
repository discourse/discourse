import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import UserMcpAuthorizations from "discourse/components/user-preferences/user-mcp-authorizations";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Integration | Component | UserMcpAuthorizations", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.mcp_server_enabled = true;
    this.model = { username: "mcp-user" };
  });

  test("renders authorization details returned by the preferences endpoint", async function (assert) {
    pretender.get("/u/mcp-user/preferences/mcp-authorizations.json", () =>
      response({
        authorizations: [
          {
            id: 42,
            client_name: "Example assistant",
            resource: "https://forum.example.com/mcp",
            scopes: ["mcp:content:read"],
            consented_at: "2026-08-01T10:00:00Z",
            last_used_at: null,
            token_count: 1,
            status: "active",
          },
        ],
      })
    );

    await render(
      <template><UserMcpAuthorizations @model={{this.model}} /></template>
    );

    assert
      .dom(".user-mcp-authorization")
      .exists("the connected application is rendered");
    assert
      .dom(".user-mcp-authorization h3")
      .hasText("Example assistant", "the client name is shown");
    assert
      .dom(".user-mcp-authorization__actions .btn-danger")
      .hasText("Revoke access", "active authorizations can be revoked");
    assert
      .dom(".user-mcp-authorization")
      .includesText("mcp:content:read", "granted scopes are shown");
  });
});
