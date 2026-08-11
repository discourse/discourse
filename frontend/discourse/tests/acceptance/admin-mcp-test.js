import { click, currentURL, fillIn, select, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Admin - MCP", function (needs) {
  let savedScopes;
  let emergencyBlockRequests;

  needs.user({ admin: true });
  needs.hooks.beforeEach(() => {
    savedScopes = null;
    emergencyBlockRequests = [];
  });

  needs.pretender((server, helper) => {
    server.get("/admin/config/site_settings.json", () =>
      helper.response({ site_settings: [] })
    );
    server.get("/admin/mcp/overview.json", () =>
      helper.response({
        enabled: false,
        endpoint: "https://forum.example.com/mcp",
        protocol_version: "2026-07-28",
        server_version: "test",
        status: "disabled",
        catalog: { tools: 0, resources: 0, prompts: 0, schema_bytes: 0 },
        metrics: {
          active_clients: 0,
          authorizations: 0,
          tokens: 0,
          errors: 0,
        },
        setup_checklist: [
          { label: "Enable server", complete: true },
          { label: "Register client", complete: true },
        ],
        warnings: [],
      })
    );
    server.get("/admin/mcp/capabilities.json", () =>
      helper.response({
        available_scopes: ["mcp:content:read", "mcp:content:write"],
        profile: {
          enabled: true,
          instructions: "",
          allowed_group_ids: [1],
          allowed_scopes: ["mcp:content:read"],
          cache_ttl_ms: 300_000,
        },
        capabilities: [
          {
            id: "tool:discourse.search",
            field_name: "capability_search",
            title: "Search Discourse",
            description: "Search visible topics and posts.",
            provider: "core",
            kind: "tool",
            risk: "read",
            required_scopes: ["mcp:content:read"],
            enabled: true,
            available: true,
            emergency_blocked: false,
          },
          {
            id: "tool:discourse.topic.create",
            field_name: "capability_create_topic",
            title: "Create topic",
            description: "Create a topic.",
            provider: "core",
            kind: "tool",
            risk: "write",
            required_scopes: ["mcp:content:write"],
            enabled: false,
            available: true,
            emergency_blocked: false,
          },
        ],
      })
    );
    server.put("/admin/mcp/configuration.json", (request) => {
      const body = new URLSearchParams(request.requestBody);
      savedScopes = body.getAll("configuration[allowed_scopes][]");
      return helper.response({ profile: {} });
    });
    server.put("/admin/mcp/capabilities/emergency-block.json", (request) => {
      const body = new URLSearchParams(request.requestBody);
      emergencyBlockRequests.push({
        capabilityId: body.get("capability_id"),
        blocked: body.get("blocked") === "true",
      });
      return helper.response({ success: true });
    });
  });

  test("can navigate away from the settings tab", async function (assert) {
    await visit("/admin/config/mcp/settings");

    assert.strictEqual(
      currentURL(),
      "/admin/config/mcp/settings",
      "the settings route renders"
    );

    await click(".admin-mcp-tabs__overview a");

    assert.strictEqual(
      currentURL(),
      "/admin/config/mcp",
      "the overview route is entered"
    );
    assert
      .dom("h2")
      .hasText("MCP server overview", "the overview content renders");
    assert
      .dom(".admin-mcp__setup")
      .doesNotExist("the completed setup checklist is hidden");
  });

  test("selects allowed scopes from the server catalog", async function (assert) {
    await visit("/admin/config/mcp/capabilities");

    assert
      .dom(".admin-mcp__configuration-form")
      .includesText(
        "Administrators are always included",
        "the group policy is explained"
      );

    await click(".admin-mcp__configuration-form .group-chooser summary");

    assert
      .dom(".admin-mcp__configuration-form .group-chooser .tag-choice.disabled")
      .hasText("admins", "the administrators group cannot be removed");

    await click(".admin-mcp__configuration-form .group-chooser summary");

    assert
      .dom(".admin-mcp__scope-select")
      .exists("allowed scopes use a multi-select control");
    assert
      .dom(".admin-mcp__scope-select .d-multi-select-trigger__selected-item")
      .hasText("mcp:content:read", "the saved scope is selected");

    await click(".admin-mcp__scope-select");

    assert
      .dom(".d-multi-select__result")
      .includesText(
        "mcp:content:write",
        "the server-provided scope is available"
      );
    assert
      .dom(".d-multi-select__result")
      .includesText("1 capability", "the option explains its catalog usage");

    await click(".d-multi-select__result");
    await click(".admin-mcp__configuration-form .btn-primary");

    assert.deepEqual(
      savedScopes,
      ["mcp:content:read", "mcp:content:write"],
      "selected scope identifiers are saved directly"
    );
  });

  test("blocks and unblocks a capability immediately", async function (assert) {
    const capabilitySelector =
      '.admin-mcp__capability[data-capability-id="tool:discourse.search"]';

    await visit("/admin/config/mcp/capabilities");
    await click(`${capabilitySelector} .admin-mcp__capability-actions button`);

    assert
      .dom(".dialog-body")
      .includesText(
        "Block Search Discourse immediately?",
        "the action explains what will be blocked"
      );

    await click(".dialog-footer .btn-primary");

    assert.deepEqual(
      emergencyBlockRequests,
      [{ capabilityId: "tool:discourse.search", blocked: true }],
      "the capability identifier is sent in the request body"
    );
    assert
      .dom(capabilitySelector)
      .includesText("Immediately blocked", "the blocked state is visible");
    assert
      .dom(`${capabilitySelector} input[type="checkbox"]`)
      .isDisabled("the blocked capability cannot be enabled");
    assert
      .dom(`${capabilitySelector} .admin-mcp__capability-actions button`)
      .hasAttribute("title", "Remove block", "the action changes to unblock");

    await click(`${capabilitySelector} .admin-mcp__capability-actions button`);

    assert.deepEqual(
      emergencyBlockRequests,
      [
        { capabilityId: "tool:discourse.search", blocked: true },
        { capabilityId: "tool:discourse.search", blocked: false },
      ],
      "the block can be removed without another confirmation"
    );
    assert
      .dom(capabilitySelector)
      .doesNotIncludeText(
        "Immediately blocked",
        "the blocked state is removed"
      );
  });

  test("filters capabilities with FormKit controls", async function (assert) {
    await visit("/admin/config/mcp/capabilities");

    assert
      .dom(".admin-mcp__capability-filters.form-kit")
      .exists("the capability filters use FormKit");
    assert
      .dom(".admin-mcp__capability")
      .exists({ count: 2 }, "all capabilities initially render");
    assert
      .dom('[name="capabilityScope"]')
      .hasValue("all", "the scope filter defaults to any scope");

    await select('[name="capabilityScope"]', "mcp:content:write");

    assert
      .dom(".admin-mcp__capability")
      .exists({ count: 1 }, "the scope selector filters capabilities");
    assert
      .dom(".admin-mcp__capability")
      .includesText(
        "Create topic",
        "the capability requiring that scope remains"
      );

    await select('[name="capabilityScope"]', "all");
    await fillIn('[name="capabilityFilter"]', "Create topic");

    assert
      .dom(".admin-mcp__capability")
      .exists({ count: 1 }, "the FormKit search field filters capabilities");
    assert
      .dom(".admin-mcp__capability")
      .includesText("Create topic", "the matching capability remains visible");
  });
});
