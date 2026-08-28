import { click, find, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import UserMcpAuthorizations from "discourse/components/user-preferences/user-mcp-authorizations";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";

module("Integration | Component | UserMcpAuthorizations", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.mcp_server_enabled = true;
    this.model = { username: "mcp-user", show_mcp_authorizations: true };
  });

  hooks.afterEach(function () {
    sinon.restore();
  });

  test("does not render when MCP authorizations are not relevant", async function (assert) {
    this.model.show_mcp_authorizations = false;

    await render(
      <template><UserMcpAuthorizations @model={{this.model}} /></template>
    );

    assert
      .dom(".user-mcp-authorizations")
      .doesNotExist("irrelevant MCP authorization history is hidden");
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
      .dom(".user-mcp-authorizations__table")
      .exists("authorizations are presented as a table");
    assert
      .dom(".user-mcp-authorizations > .control-label")
      .hasText(
        i18n("user.mcp_authorizations.title"),
        "the heading follows the Security section pattern"
      );
    assert
      .dom(".user-mcp-authorizations__table thead .d-table__header-cell")
      .exists({ count: 3 }, "the table describes each column");
    assert
      .dom(".user-mcp-authorizations__table thead th:nth-child(1)")
      .hasText(
        i18n("user.mcp_authorizations.application"),
        "the application column is labelled"
      );
    assert
      .dom(".user-mcp-authorizations__table thead th:nth-child(2)")
      .hasText(
        i18n("user.mcp_authorizations.details"),
        "the details column is labelled"
      );
    assert
      .dom(".user-mcp-authorizations__table thead th:nth-child(3)")
      .hasText(
        i18n("user.mcp_authorizations.status"),
        "the status column is labelled"
      );
    assert
      .dom(".user-mcp-authorization__application")
      .hasText(
        "Example assistant",
        "the application column only shows the name"
      );
    assert
      .dom('.user-mcp-authorization__status[data-state="active"]')
      .hasText(
        i18n("user.mcp_authorizations.statuses.active"),
        "the authorization status is easy to scan"
      );
    assert
      .dom(".user-mcp-authorization__details-cell")
      .includesText(
        i18n("user.mcp_authorizations.active_tokens", { count: 1 }),
        "active token usage is grouped with the authorization details"
      );
    assert
      .dom(".user-mcp-authorization__details-cell")
      .includesText(
        i18n("user.mcp_authorizations.authorized"),
        "the authorization date is grouped with the other details"
      );
    assert
      .dom(".user-mcp-authorization__status-cell .btn-default")
      .hasText(
        i18n("user.mcp_authorizations.revoke"),
        "active authorizations can be revoked"
      );
    assert
      .dom(".user-mcp-authorization__status-cell .btn-danger")
      .doesNotExist("the compact row does not overemphasize the revoke action");
    assert
      .dom(".user-mcp-authorization__actions")
      .doesNotExist("the table does not reserve a separate actions column");
    assert
      .dom(".user-mcp-authorization__permissions-list")
      .doesNotExist("permissions are collapsed initially");
  });

  test("expands granted permissions", async function (assert) {
    pretender.get("/u/mcp-user/preferences/mcp-authorizations.json", () =>
      response({
        authorizations: [
          {
            id: 42,
            client_name: "Example assistant",
            resource: "https://forum.example.com/mcp",
            scopes: [
              "mcp:content:read:a-very-long-permission-name-that-must-wrap",
            ],
            consented_at: "2026-08-01T10:00:00Z",
            last_used_at: null,
            token_count: 1,
            status: "active",
          },
        ],
      })
    );

    await render(
      <template>
        <div style="width: 31.25rem">
          <UserMcpAuthorizations @model={{this.model}} />
        </div>
      </template>
    );

    const applicationWidth = find(
      ".user-mcp-authorization__application"
    ).getBoundingClientRect().width;
    const statusWidth = find(
      ".user-mcp-authorization__status-cell"
    ).getBoundingClientRect().width;

    assert
      .dom(".user-mcp-authorization__permissions-toggle")
      .hasText(
        i18n("user.mcp_authorizations.permissions", { count: 1 }),
        "the permission count is shown"
      );

    await click(".user-mcp-authorization__permissions-toggle");

    assert
      .dom(".user-mcp-authorization__permissions-list")
      .includesText("mcp:content:read", "granted scopes are shown on request");
    assert
      .dom(".user-mcp-authorization__permissions-toggle")
      .hasAttribute("aria-expanded", "true", "the expanded state is exposed");
    assert.strictEqual(
      find(".user-mcp-authorization__application").getBoundingClientRect()
        .width,
      applicationWidth,
      "expanding permissions does not resize the application column"
    );
    assert.strictEqual(
      find(".user-mcp-authorization__status-cell").getBoundingClientRect()
        .width,
      statusWidth,
      "expanding permissions does not resize the status column"
    );
  });

  test("shows authorizations while the server is disabled", async function (assert) {
    this.siteSettings.mcp_server_enabled = false;
    pretender.get("/u/mcp-user/preferences/mcp-authorizations.json", () =>
      response({
        authorizations: [
          {
            id: 42,
            client_name: "Example assistant",
            scopes: ["mcp:content:read"],
            consented_at: "2026-08-01T10:00:00Z",
            last_used_at: null,
            token_count: 1,
            status: "server_disabled",
          },
        ],
      })
    );

    await render(
      <template><UserMcpAuthorizations @model={{this.model}} /></template>
    );

    assert
      .dom('.user-mcp-authorization__status[data-state="server_disabled"]')
      .hasText(
        i18n("user.mcp_authorizations.statuses.server_disabled"),
        "the temporary server state is explained"
      );
    assert
      .dom(".user-mcp-authorization__status-cell .btn-default")
      .hasText(
        i18n("user.mcp_authorizations.revoke"),
        "unusable authorizations can still be revoked"
      );
  });

  test("shows revoked authorization history", async function (assert) {
    pretender.get("/u/mcp-user/preferences/mcp-authorizations.json", () =>
      response({
        authorizations: [
          {
            id: 42,
            client_name: "Former assistant",
            scopes: ["mcp:content:read"],
            consented_at: "2026-08-01T10:00:00Z",
            last_used_at: null,
            token_count: 0,
            status: "revoked",
          },
        ],
      })
    );

    await render(
      <template><UserMcpAuthorizations @model={{this.model}} /></template>
    );

    assert
      .dom('.user-mcp-authorization__status[data-state="revoked"]')
      .hasText(
        i18n("user.mcp_authorizations.statuses.revoked"),
        "revoked authorization history remains visible"
      );
    assert
      .dom(".user-mcp-authorization__status-cell .btn-default")
      .doesNotExist("revoked authorizations have no available action");
  });

  test("quotes the application name in the revoke confirmation", async function (assert) {
    const confirm = sinon.stub(this.owner.lookup("service:dialog"), "confirm");
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
    await click(".user-mcp-authorization__status-cell .btn-default");

    assert.strictEqual(
      confirm.firstCall.args[0].message,
      i18n("user.mcp_authorizations.revoke_confirm", {
        name: "Example assistant",
      }),
      "the application name is clearly delimited"
    );
  });

  test("keeps revoked authorization history visible", async function (assert) {
    const confirm = sinon.stub(this.owner.lookup("service:dialog"), "confirm");
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
    pretender.delete("/u/mcp-user/preferences/mcp-authorizations/42.json", () =>
      response(204)
    );

    await render(
      <template><UserMcpAuthorizations @model={{this.model}} /></template>
    );
    await click(".user-mcp-authorization__status-cell .btn-default");
    await confirm.firstCall.args[0].didConfirm();
    await settled();

    assert
      .dom('.user-mcp-authorization__status[data-state="revoked"]')
      .hasText(
        i18n("user.mcp_authorizations.statuses.revoked"),
        "the revoked authorization remains in the history"
      );
    assert
      .dom(".user-mcp-authorization__status-cell .btn-default")
      .doesNotExist("the revoked authorization has no available action");
  });
});
