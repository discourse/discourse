import {
  click,
  currentURL,
  fillIn,
  findAll,
  select,
  visit,
  waitUntil,
} from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import stubIntersectionObserver from "discourse/tests/helpers/stub-intersection-observer";
import {
  disableLoadMoreObserver,
  enableLoadMoreObserver,
} from "discourse/ui-kit/d-load-more";
import { i18n } from "discourse-i18n";

const refreshedClientName = "Updated client";

acceptance("Admin - MCP", function (needs) {
  let savedAccessRule;
  let emergencyBlockRequests;
  let refreshClientRequests;
  let setupComplete;
  let activityRequests;
  let authorizationRequests;
  let clientRequests;
  let savedPrimitiveIds;

  needs.user({ admin: true });
  needs.hooks.beforeEach(() => {
    savedAccessRule = null;
    emergencyBlockRequests = [];
    refreshClientRequests = [];
    setupComplete = true;
    activityRequests = [];
    authorizationRequests = [];
    clientRequests = [];
    savedPrimitiveIds = null;
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
          approved_oauth_clients: 0,
          authorizations: 0,
          tokens: 0,
          errors: 0,
        },
        setup_checklist: [
          { label: "Enable server", complete: setupComplete },
          { label: "Register client", complete: true },
        ],
        warnings: [],
      })
    );
    const capabilitiesResponse = () =>
      helper.response({
        initial_scope: "mcp:profile:read",
        available_scopes: [
          "chat:read",
          "mcp:content:read",
          "mcp:content:write",
          "mcp:profile:read",
          "voting:write",
        ],
        access_rules: [
          {
            group_id: 1,
            group_name: "admins",
            scopes: [
              "chat:read",
              "mcp:content:read",
              "mcp:content:write",
              "mcp:profile:read",
              "voting:write",
            ],
            pre_registered: true,
            deletable: false,
          },
          {
            group_id: 42,
            group_name: "writers",
            scopes: [
              "mcp:content:read",
              "mcp:content:write",
              "mcp:profile:read",
            ],
            pre_registered: false,
            deletable: true,
          },
        ],
        primitives: [
          {
            id: "tool:discourse_search",
            field_name: "primitive_search",
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
            id: "tool:discourse_topic_create",
            field_name: "primitive_create_topic",
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
          {
            id: "resource_template:chat.channel",
            field_name: "primitive_chat_channel",
            title: "Chat channel",
            description: "A visible chat channel.",
            provider: "chat",
            kind: "resource_template",
            risk: "read",
            required_scopes: ["chat:read"],
            enabled: false,
            available: true,
            emergency_blocked: false,
          },
          {
            id: "tool:discourse_topic_vote",
            field_name: "primitive_topic_vote",
            title: "Set topic vote",
            description: "Votes in a topic poll.",
            provider: "voting",
            kind: "tool",
            risk: "write",
            required_scopes: ["voting:write"],
            enabled: false,
            available: true,
            emergency_blocked: false,
          },
        ],
      });
    server.get("/admin/mcp/access.json", capabilitiesResponse);
    server.get("/admin/mcp/capabilities.json", capabilitiesResponse);
    server.put("/admin/mcp/capabilities.json", (request) => {
      const body = new URLSearchParams(request.requestBody);
      savedPrimitiveIds = body.getAll("primitive_ids[]");
      return helper.response({ success: true });
    });
    server.get("/admin/mcp/authorizations.json", (request) => {
      authorizationRequests.push(request.queryParams);
      if (request.queryParams.filter === "former") {
        return helper.response({
          authorizations: [
            {
              id: 18,
              username: "alex",
              client_name: "Former assistant",
              client_id: "former-client",
              scopes: ["mcp:content:read"],
              status: "revoked",
              last_used_at: null,
            },
          ],
          meta: {},
        });
      }
      if (request.queryParams.cursor) {
        return helper.response({
          authorizations: [
            {
              id: 18,
              username: "alex",
              client_name: "Former assistant",
              client_id: "former-client",
              scopes: ["mcp:content:read"],
              status: "revoked",
              last_used_at: null,
            },
          ],
          meta: {},
        });
      }
      return helper.response({
        authorizations: [
          {
            id: 19,
            username: "sam",
            client_name: "Example assistant",
            client_id: "example-client",
            scopes: ["mcp:content:read"],
            status: "access_removed",
            last_used_at: null,
          },
        ],
        meta: { next_cursor: 19 },
      });
    });
    server.get("/admin/mcp/clients.json", (request) => {
      clientRequests.push(request.queryParams);
      if (request.queryParams.filter === "older") {
        return helper.response({
          clients: [
            {
              id: 6,
              client_id: "older-client",
              name: "Older client",
              registration_type: "pre_registered",
              trust_state: "approved",
              blocked: false,
              last_seen_at: null,
              authorization_count: 0,
            },
          ],
          meta: {},
        });
      }
      if (request.queryParams.cursor) {
        return helper.response({
          clients: [
            {
              id: 6,
              client_id: "older-client",
              name: "Older client",
              registration_type: "pre_registered",
              trust_state: "approved",
              blocked: false,
              last_seen_at: null,
              authorization_count: 0,
            },
          ],
          meta: {},
        });
      }
      return helper.response({
        clients: [
          {
            id: 7,
            client_id: "https://client.example.com/oauth/client.json",
            name: "Example client",
            registration_type: "cimd",
            trust_state: "approved",
            blocked: false,
            last_seen_at: null,
            authorization_count: 1,
          },
          {
            id: 8,
            client_id: "blocked-client",
            name: "Blocked client",
            registration_type: "pre_registered",
            trust_state: "blocked",
            blocked: true,
            last_seen_at: null,
            authorization_count: 0,
          },
        ],
        meta: { next_cursor: 7 },
      });
    });
    server.post("/admin/mcp/clients/7/refresh.json", () => {
      refreshClientRequests.push(7);
      return helper.response({
        client: {
          id: 7,
          client_id: "https://client.example.com/oauth/client.json",
          name: refreshedClientName,
          registration_type: "cimd",
          trust_state: "approved",
          blocked: false,
          last_seen_at: null,
          authorization_count: 1,
        },
      });
    });
    server.get("/admin/mcp/activity.json", (request) => {
      activityRequests.push(request.queryParams);

      const metrics = {
        tool_calls: 2,
        errors: 1,
        rate_limits: 0,
        p95_latency_ms: 25,
      };
      if (request.queryParams.filter !== "search") {
        return helper.response({ activity: [], metrics, meta: {} });
      }

      if (request.queryParams.cursor) {
        return helper.response({
          activity: [
            {
              id: 1,
              created_at: "2026-08-28T10:00:00Z",
              method: "tools/call",
              tool: "discourse_search_older",
              username: "sam",
              outcome: "error",
              duration_ms: 20,
              request_id: "request-older",
            },
          ],
          meta: {},
        });
      }

      return helper.response({
        activity: [
          {
            id: 2,
            created_at: "2026-08-28T11:00:00Z",
            method: "tools/call",
            tool: "discourse_search_newer",
            username: "sam",
            outcome: "error",
            duration_ms: 25,
            request_id: "request-newer",
          },
        ],
        metrics,
        meta: { next_cursor: 2 },
      });
    });
    server.put("/admin/mcp/access/:group_id.json", (request) => {
      const body = new URLSearchParams(request.requestBody);
      savedAccessRule = {
        groupId: request.url.split("/").at(-1).split(".")[0],
        scopes: body.getAll("scopes[]"),
      };
      return helper.response({
        access_rules: [
          {
            group_id: 1,
            group_name: "admins",
            scopes: [
              "chat:read",
              "mcp:content:read",
              "mcp:content:write",
              "mcp:profile:read",
              "voting:write",
            ],
            pre_registered: true,
            deletable: false,
          },
          {
            group_id: 42,
            group_name: "writers",
            scopes: body.getAll("scopes[]"),
            pre_registered: false,
            deletable: true,
          },
        ],
      });
    });
    server.put("/admin/mcp/capabilities/emergency-block.json", (request) => {
      const body = new URLSearchParams(request.requestBody);
      emergencyBlockRequests.push({
        primitiveId: body.get("primitive_id"),
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
      .hasText(
        i18n("admin.config.mcp.overview.title"),
        "the overview content renders"
      );
    assert
      .dom(".admin-mcp__usage")
      .includesText(
        i18n("admin.config.mcp.overview.approved_oauth_clients"),
        "the overview names approved OAuth clients"
      );
    assert
      .dom(".admin-mcp__setup")
      .doesNotExist("the completed setup checklist is hidden");
  });

  test("shows the setup checklist while setup is incomplete", async function (assert) {
    setupComplete = false;

    await visit("/admin/config/mcp");

    assert
      .dom(".admin-mcp__setup")
      .exists("the incomplete setup checklist is visible");
  });

  test("prefills known OAuth client applications", async function (assert) {
    await visit("/admin/config/mcp/clients/new");

    assert
      .dom(".admin-mcp__client-presets")
      .exists("the application choices are shown first");
    assert
      .dom("[data-client-preset-id]")
      .exists(
        { count: 6 },
        "the known applications and custom option are shown"
      );
    assert
      .dom(".admin-mcp__client-form")
      .doesNotExist("the form is hidden until an application is selected");

    await click('[data-client-preset-id="codex"] button');

    assert
      .dom(".admin-mcp__client-presets")
      .doesNotExist("the application choices are hidden while editing");
    assert
      .dom(".admin-mcp__client-form")
      .includesText(
        i18n("admin.config.mcp.clients.preset_help.codex"),
        "the selected application instructions are shown"
      );
    assert.dom('[name="name"]').hasValue("Codex", "Codex has a name");
    assert.dom('[name="client_id"]').hasValue("codex", "Codex has a client ID");
    assert
      .dom('[name="redirect_uris"]')
      .hasValue(
        "http://127.0.0.1/callback",
        "Codex has its portless loopback callback"
      );

    await click(".admin-mcp__change-client-preset");
    await click('[data-client-preset-id="chatgpt"] button');

    assert
      .dom(".admin-mcp__client-form")
      .includesText(
        i18n("admin.config.mcp.clients.preset_help.chatgpt"),
        "the ChatGPT instructions explain when registration is needed"
      );
    assert
      .dom('[name="client_id"]')
      .hasValue(
        "https://chatgpt.com/oauth/client.json",
        "ChatGPT has its stable metadata client ID"
      );
    assert
      .dom('[name="redirect_uris"]')
      .hasValue(
        "https://chatgpt.com/connector_platform_oauth_redirect",
        "ChatGPT has its stable hosted callback"
      );

    await click(".admin-mcp__change-client-preset");
    await click('[data-client-preset-id="claude_code"] button');

    assert
      .dom('[name="redirect_uris"]')
      .hasValue(
        "http://localhost:8080/callback",
        "Claude Code has a fixed callback port"
      );
    assert
      .dom(".admin-mcp__client-form")
      .includesText(
        i18n("admin.config.mcp.clients.preset_help.claude_code"),
        "the application instructions explain how to use the fixed port"
      );

    await click(".admin-mcp__change-client-preset");
    await click('[data-client-preset-id="mcp_inspector"] button');

    assert
      .dom('[name="redirect_uris"]')
      .hasValue(
        "http://localhost:6274/oauth/callback\nhttp://127.0.0.1:6276/oauth/callback",
        "MCP Inspector allows its web and command-line callbacks"
      );

    await click(".admin-mcp__change-client-preset");
    await click('[data-client-preset-id="visual_studio_code"] button');

    assert
      .dom('[name="redirect_uris"]')
      .hasValue(
        "http://127.0.0.1:33418\nhttps://vscode.dev/redirect",
        "Visual Studio Code allows its loopback and hosted callbacks"
      );

    await click(".admin-mcp__change-client-preset");
    await click('[data-client-preset-id="custom"] button');

    assert.dom('[name="name"]').hasValue("", "a custom client starts empty");
    assert
      .dom('[name="client_id"]')
      .hasValue("", "a custom client ID starts empty");
  });

  test("adds group access on a dedicated page", async function (assert) {
    await visit("/admin/config/mcp/access");
    await click(".admin-mcp__access-section .btn-primary");

    assert.strictEqual(
      currentURL(),
      "/admin/config/mcp/access/new",
      "the add action opens a dedicated route"
    );
    assert
      .dom(".admin-mcp__form-card")
      .includesText(
        i18n("admin.config.mcp.access.new_title"),
        "the add page follows the OAuth client form pattern"
      );
    assert
      .dom(".admin-mcp__access-form")
      .exists("the group access form is shown on the dedicated page");
    assert
      .dom(".admin-mcp__scope-select .d-multi-select-trigger__selected-item")
      .hasText("mcp:profile:read", "the initial scope is selected");
  });

  test("edits the eligible scopes for one group", async function (assert) {
    await visit("/admin/config/mcp/access");

    assert.strictEqual(
      currentURL(),
      "/admin/config/mcp/access",
      "the access route loads directly"
    );
    assert
      .dom(".admin-mcp-tabs__access")
      .hasText(
        i18n("admin.config.mcp.tabs.access"),
        "the access tab is selected"
      );
    assert
      .dom(".admin-mcp__access-section > .d-page-subheader h2")
      .hasText(
        i18n("admin.config.mcp.access.title"),
        "the page has one access heading"
      );
    await click('[data-group-id="42"] .admin-mcp__edit-access-rule');

    assert.strictEqual(
      currentURL(),
      "/admin/config/mcp/access/42/edit",
      "the edit action opens a dedicated route"
    );

    assert
      .dom(".admin-mcp__scope-select")
      .exists("eligible scopes use a multi-select control");
    assert
      .dom(".admin-mcp__scope-select .d-multi-select-trigger__selected-item")
      .exists({ count: 3 }, "the group's saved scopes are selected");

    const initialScope = findAll(
      ".admin-mcp__scope-select .d-multi-select-trigger__selected-item"
    ).find((scope) => scope.textContent.includes("mcp:profile:read"));
    await click(initialScope);
    assert
      .dom(".admin-mcp__scope-select .d-multi-select-trigger__selected-item")
      .exists({ count: 3 }, "the initial scope cannot be removed");

    await click(".admin-mcp__scope-select");

    const chatScopeResult = findAll(".d-multi-select__result").find((result) =>
      result.textContent.includes("chat:read")
    );

    assert
      .dom(chatScopeResult)
      .includesText("chat:read", "the server-provided scope is available");
    assert
      .dom(chatScopeResult)
      .includesText(
        i18n("admin.config.mcp.access.scope_primitives", { count: 1 }),
        "the option explains its primitive usage"
      );

    await click(chatScopeResult);
    await click(".admin-mcp__access-form .btn-primary");

    assert.strictEqual(
      savedAccessRule.groupId,
      "42",
      "the edited group is saved"
    );
    assert.deepEqual(
      savedAccessRule.scopes.sort(),
      [
        "chat:read",
        "mcp:content:read",
        "mcp:content:write",
        "mcp:profile:read",
      ],
      "selected scope identifiers are saved directly"
    );
  });

  test("shows access as one row per group", async function (assert) {
    await visit("/admin/config/mcp/access");

    assert
      .dom(".admin-mcp__access-table")
      .exists("group access is presented as a table");
    assert
      .dom(".admin-mcp__access-table thead th")
      .exists({ count: 4 }, "edit and delete have separate columns");
    assert
      .dom(".admin-mcp__access-table thead th:first-child")
      .hasText(
        i18n("admin.config.mcp.access.groups"),
        "the first column is Groups"
      );
    assert
      .dom(".admin-mcp__access-table thead th:nth-child(3) .sr-only")
      .hasText(
        i18n("admin.config.mcp.access.edit"),
        "the untitled edit column remains accessible"
      );
    assert
      .dom(".admin-mcp__access-table thead th:nth-child(4) .sr-only")
      .hasText(
        i18n("admin.config.mcp.access.delete"),
        "the untitled delete column remains accessible"
      );
    assert
      .dom(".admin-mcp__access-table tbody tr")
      .exists(
        { count: 2 },
        "the pre-registered Admins row and saved group row render"
      );
    assert
      .dom(".admin-mcp__access-table tbody tr:first-child")
      .includesText("admins", "the pre-registered Admins row is shown");
    assert
      .dom(
        ".admin-mcp__access-table tbody tr:first-child td:nth-child(3) .admin-mcp__edit-access-rule"
      )
      .exists("the Admins scopes can be edited");
    assert
      .dom(
        ".admin-mcp__access-table tbody tr:first-child td:nth-child(4) .admin-mcp__delete-access-rule"
      )
      .doesNotExist("the pre-registered Admins row cannot be removed");
    assert
      .dom(".admin-mcp__access-table tbody tr:last-child")
      .includesText("writers", "the persisted group row is shown");
    assert
      .dom(
        ".admin-mcp__access-table tbody tr:last-child td:nth-child(4) .admin-mcp__delete-access-rule"
      )
      .exists("deletable groups keep the separate delete column");
  });

  test("labels user grants as authorizations", async function (assert) {
    await visit("/admin/config/mcp/authorizations");

    assert
      .dom(".admin-mcp-tabs__authorizations")
      .hasText(
        i18n("admin.config.mcp.tabs.authorizations"),
        "the tab names the OAuth records"
      );
    assert
      .dom(".admin-mcp h2")
      .hasText(
        i18n("admin.config.mcp.authorizations.title"),
        "the page heading matches the tab"
      );
    assert
      .dom(".admin-mcp__authorizations-table th:nth-child(3)")
      .hasText(
        i18n("admin.config.mcp.authorizations.scopes"),
        "the table uses the OAuth scope term"
      );
    assert
      .dom(".admin-mcp__authorizations-table tbody td:nth-child(3) code")
      .exists("scope identifiers use monospace text");
    assert
      .dom('.admin-mcp__status[data-state="access_removed"]')
      .hasText(
        i18n("admin.config.mcp.values.authorization_status.access_removed"),
        "the current access restriction is shown"
      );
  });

  test("shows client actions in the expected order and refreshes metadata", async function (assert) {
    await visit("/admin/config/mcp/clients");

    assert
      .dom(".d-page-subheader__learn-more a")
      .hasAttribute(
        "href",
        "https://meta.discourse.org/t/connecting-your-apps-to-discourse-mcp-server/411637#p-2033870-connecting-apps-via-oauth-2",
        "the OAuth clients documentation is linked"
      );
    assert
      .dom(".admin-mcp__table th:last-child .sr-only")
      .hasText(
        i18n("admin.config.mcp.clients.actions"),
        "the untitled action column remains accessible"
      );
    assert
      .dom(
        ".admin-mcp__table tbody tr:first-child .d-table__cell-actions button:first-child"
      )
      .hasText(
        i18n("admin.config.mcp.actions.refresh_metadata"),
        "refresh metadata is the first action"
      )
      .hasClass("--primary", "refresh metadata uses the tertiary action color");
    assert
      .dom(
        ".admin-mcp__table tbody tr:first-child .d-table__cell-actions button:last-child"
      )
      .hasText(
        i18n("admin.config.mcp.clients.block"),
        "block is the last action"
      )
      .hasClass("btn-danger", "block uses the danger style");
    assert
      .dom(
        ".admin-mcp__table tbody tr:last-child .admin-mcp__toggle-client-block"
      )
      .hasText(
        i18n("admin.config.mcp.clients.unblock"),
        "blocked clients show Unblock"
      )
      .hasClass("btn-default", "unblock uses the neutral default style");

    await click(".admin-mcp__refresh-client");

    assert.deepEqual(refreshClientRequests, [7], "metadata is refreshed");
    assert
      .dom(".admin-mcp__table tbody .d-table__overview-name")
      .hasText(refreshedClientName, "the refreshed metadata updates the row");
  });

  test("filters clients and authorizations on the server", async function (assert) {
    await visit("/admin/config/mcp/clients");
    await fillIn(".admin-mcp__table-filter input", "older");
    await waitUntil(() =>
      clientRequests.some((request) => request.filter === "older")
    );

    assert
      .dom(".admin-mcp__table tbody tr")
      .exists({ count: 1 }, "the server-filtered client replaces the table");
    assert
      .dom(".admin-mcp__table")
      .includesText("Older client", "the matching client is shown");

    await visit("/admin/config/mcp/authorizations");
    await fillIn(".admin-mcp__table-filter input", "former");
    await waitUntil(() =>
      authorizationRequests.some((request) => request.filter === "former")
    );

    assert
      .dom(".admin-mcp__authorizations-table tbody tr")
      .exists(
        { count: 1 },
        "the server-filtered authorization replaces the table"
      );
    assert
      .dom(".admin-mcp__authorizations-table")
      .includesText("Former assistant", "the matching authorization is shown");
  });

  test("loads older clients and authorizations", async function (assert) {
    enableLoadMoreObserver();
    const observations = stubIntersectionObserver();

    try {
      await visit("/admin/config/mcp/clients");
      await observations
        .find(({ element }) => element.closest(".admin-mcp__load-more"))
        .trigger();
      await waitUntil(() =>
        clientRequests.some((request) => request.cursor === "7")
      );

      assert
        .dom(".admin-mcp__table tbody tr")
        .exists({ count: 3 }, "the older client is appended");

      await visit("/admin/config/mcp/authorizations");
      await observations
        .findLast(({ element }) => element.closest(".admin-mcp__load-more"))
        .trigger();
      await waitUntil(() =>
        authorizationRequests.some((request) => request.cursor === "19")
      );

      assert
        .dom(".admin-mcp__authorizations-table tbody tr")
        .exists({ count: 2 }, "the older authorization is appended");
    } finally {
      disableLoadMoreObserver();
    }
  });

  test("labels audited calls as tool calls", async function (assert) {
    await visit("/admin/config/mcp/activity");

    assert
      .dom(".admin-mcp__activity-filters select option:first-child")
      .hasText(
        i18n("admin.config.mcp.values.activity_outcome.all"),
        "the unfiltered option names the outcome filter"
      );
    assert
      .dom(".admin-mcp__activity-metrics")
      .includesText(
        i18n("admin.config.mcp.activity.tool_calls"),
        "the metric describes the audited method"
      );
  });

  test("filters on the server and automatically loads the next filtered page", async function (assert) {
    enableLoadMoreObserver();
    const observations = stubIntersectionObserver();

    try {
      await visit("/admin/config/mcp/activity");
      await fillIn(".admin-mcp__activity-filters input", "search");
      await waitUntil(() =>
        activityRequests.some((request) => request.filter === "search")
      );
      await select(".admin-mcp__activity-filters select", "error");
      await waitUntil(() =>
        activityRequests.some(
          (request) =>
            request.filter === "search" && request.outcome === "error"
        )
      );

      assert
        .dom(".admin-mcp__activity-table tbody tr")
        .exists({ count: 1 }, "the filtered first page replaces the table");
      assert
        .dom(".admin-mcp__activity-table")
        .includesText("discourse_search_newer", "the server result is shown");
      assert
        .dom(".admin-mcp__load-more")
        .exists("automatic loading is enabled while a cursor is present");

      await observations
        .find(({ element }) => element.closest(".admin-mcp__load-more"))
        .trigger();

      await waitUntil(() =>
        activityRequests.some((request) => request.cursor === "2")
      );

      assert.deepEqual(
        activityRequests.at(-1),
        { cursor: "2", filter: "search", outcome: "error" },
        "the cursor request preserves every active filter"
      );
      assert
        .dom(".admin-mcp__activity-table tbody tr")
        .exists({ count: 2 }, "the next filtered page is appended");
      assert
        .dom(".admin-mcp__activity-table")
        .includesText("discourse_search_older", "the older result is loaded");
      assert
        .dom(".admin-mcp__activity-metrics")
        .includesText("25 ms", "the initial metrics remain visible");
    } finally {
      disableLoadMoreObserver();
    }
  });

  test("blocks and unblocks a primitive immediately", async function (assert) {
    const primitiveSelector =
      '.admin-mcp__primitive[data-primitive-id="tool:discourse_search"]';

    await visit("/admin/config/mcp/capabilities");
    await click(`${primitiveSelector} .admin-mcp__primitive-actions button`);

    assert.dom(".dialog-body").includesText(
      i18n("admin.config.mcp.confirm_emergency_block", {
        name: "Search Discourse",
      }),
      "the action explains what will be blocked"
    );

    await click(".dialog-footer .btn-primary");

    assert.deepEqual(
      emergencyBlockRequests,
      [{ primitiveId: "tool:discourse_search", blocked: true }],
      "the primitive identifier is sent in the request body"
    );
    assert
      .dom(primitiveSelector)
      .includesText(
        i18n("admin.config.mcp.primitives.emergency_blocked"),
        "the blocked state is visible"
      );
    assert
      .dom(`${primitiveSelector} input[type="checkbox"]`)
      .isDisabled("the blocked primitive cannot be enabled");
    assert
      .dom(`${primitiveSelector} .admin-mcp__primitive-actions button`)
      .hasAttribute(
        "title",
        i18n("admin.config.mcp.actions.unblock_primitive"),
        "the action changes to unblock"
      );

    await click(`${primitiveSelector} .admin-mcp__primitive-actions button`);

    assert.deepEqual(
      emergencyBlockRequests,
      [
        { primitiveId: "tool:discourse_search", blocked: true },
        { primitiveId: "tool:discourse_search", blocked: false },
      ],
      "the block can be removed without another confirmation"
    );
    assert
      .dom(primitiveSelector)
      .doesNotIncludeText(
        i18n("admin.config.mcp.primitives.emergency_blocked"),
        "the blocked state is removed"
      );
  });

  test("groups primitives by scope, provider, and type", async function (assert) {
    await visit("/admin/config/mcp/capabilities");

    assert
      .dom(".admin-mcp-tabs__capabilities")
      .hasText(
        i18n("admin.config.mcp.tabs.capabilities"),
        "the capabilities tab uses the MCP term"
      );
    assert
      .dom(".admin-mcp h2")
      .hasText(
        i18n("admin.config.mcp.capabilities.title"),
        "the page heading uses the MCP term"
      );
    assert
      .dom(
        ".admin-mcp > .d-page-subheader:first-child .d-page-subheader__description"
      )
      .hasText(
        i18n("admin.config.mcp.capabilities.description"),
        "the page explains how primitives relate to capabilities"
      );
    assert
      .dom(".admin-mcp__primitive-filters.form-kit")
      .exists("the primitive filters use FormKit");
    assert
      .dom(".admin-mcp__primitives-description")
      .hasText(
        i18n("admin.config.mcp.primitives.picker_description"),
        "the primitive default state remains explained"
      );
    assert
      .dom(".admin-mcp__primitive-browser")
      .exists("the primitive browser renders below the section heading");
    assert
      .dom(".admin-mcp__primitive")
      .exists({ count: 4 }, "all primitives initially render");
    assert
      .dom('[name="primitiveGroupBy"]')
      .hasValue("scope", "primitives are grouped by scope by default");
    assert
      .dom(
        ".admin-mcp__primitive-panel-header > .admin-mcp__results-count + .admin-mcp__primitive-group-actions"
      )
      .exists("the visible primitive actions follow the result count");

    assert
      .dom('.admin-mcp__primitive-group[data-primitive-group-id="all"]')
      .includesText(
        i18n("admin.config.mcp.primitives.group_count", {
          enabled: 1,
          total: 4,
        }),
        "the group shows enabled and total counts"
      );

    await click(
      '.admin-mcp__primitive-group[data-primitive-group-id="mcp:content:write"]'
    );

    assert
      .dom(".admin-mcp__primitive")
      .exists({ count: 1 }, "selecting a scope shows its primitives");
    assert
      .dom(".admin-mcp__primitive")
      .includesText(
        "Create topic",
        "the primitive requiring that scope remains"
      );

    await select('[name="primitiveGroupBy"]', "provider");
    await click('.admin-mcp__primitive-group[data-primitive-group-id="chat"]');

    assert
      .dom(".admin-mcp__primitive")
      .exists({ count: 1 }, "selecting a provider shows its primitives");
    assert
      .dom(".admin-mcp__primitive")
      .includesText("Chat channel", "the provider primitive remains");

    await select('[name="primitiveGroupBy"]', "kind");
    await click(
      '.admin-mcp__primitive-group[data-primitive-group-id="resource_template"]'
    );

    assert
      .dom(".admin-mcp__primitive")
      .exists({ count: 1 }, "selecting a type shows its primitives");
    assert
      .dom(".admin-mcp__primitive")
      .includesText("Chat channel", "the resource template remains");

    await fillIn('[name="primitiveFilter"]', "vote");

    assert
      .dom(".admin-mcp__primitive")
      .exists({ count: 1 }, "search uses the full primitive set");
    assert
      .dom(".admin-mcp__primitive")
      .includesText("Set topic vote", "the matching primitive is visible");
    assert
      .dom('.admin-mcp__primitive-group[data-primitive-group-id="all"]')
      .hasClass("is-selected", "search returns to all primitives");

    await fillIn('[name="primitiveFilter"]', "");

    assert
      .dom(".admin-mcp__primitive")
      .exists({ count: 4 }, "clearing search restores the full primitive set");

    await fillIn('[name="primitiveFilter"]', "chat");

    assert
      .dom(".admin-mcp__primitive")
      .exists({ count: 1 }, "replacing the search term refilters the full set");
    assert
      .dom(".admin-mcp__primitive")
      .includesText("Chat channel", "the replacement match is visible");
  });

  test("floats the save action while primitive changes are unsaved", async function (assert) {
    await visit("/admin/config/mcp/capabilities");

    assert
      .dom(
        ".admin-mcp__primitive-selection-form .form-kit__actions.is-floating"
      )
      .doesNotExist("the save action is not floating before anything changes");

    await click('[name="primitive_create_topic"]');

    assert
      .dom(
        ".admin-mcp__primitive-selection-form .form-kit__actions.is-floating"
      )
      .exists("the save action floats when a primitive changes");

    await click(
      ".admin-mcp__primitive-selection-form .form-kit__actions .btn-primary"
    );

    assert.deepEqual(
      savedPrimitiveIds,
      ["tool:discourse_search", "tool:discourse_topic_create"],
      "the selected primitives are saved"
    );
    assert
      .dom(
        ".admin-mcp__primitive-selection-form .form-kit__actions.is-floating"
      )
      .doesNotExist("the save action returns to the page after saving");

    await click('[name="primitive_create_topic"]');

    assert
      .dom(
        ".admin-mcp__primitive-selection-form .form-kit__actions.is-floating"
      )
      .exists("later changes are compared with the newly saved value");

    await click('[name="primitive_create_topic"]');

    assert
      .dom(
        ".admin-mcp__primitive-selection-form .form-kit__actions.is-floating"
      )
      .doesNotExist("restoring the newly saved value clears the change");
  });

  test("clears a primitive change when its saved value is restored", async function (assert) {
    await visit("/admin/config/mcp/capabilities");

    await click('[name="primitive_create_topic"]');
    await click('[name="primitive_create_topic"]');

    assert
      .dom(
        ".admin-mcp__primitive-selection-form .form-kit__actions.is-floating"
      )
      .doesNotExist(
        "the save action stops floating after the change is undone"
      );

    await click(".admin-mcp-tabs__access a");

    assert.strictEqual(
      currentURL(),
      "/admin/config/mcp/access",
      "restoring the saved value allows navigation without a dirty-form warning"
    );
  });
});
