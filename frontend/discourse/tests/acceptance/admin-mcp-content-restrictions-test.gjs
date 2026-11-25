import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

const PluginRuleCard = <template>
  <p class="plugin-rule-card">{{@ruleKind.name}}</p>
</template>;

function ruleKind(name, overrides = {}) {
  return {
    name,
    provider: "core",
    admin_component_id: name,
    active: false,
    config: null,
    updated_at: null,
    updated_by: null,
    disables: [],
    newly_disables: [],
    restricts: [],
    ...overrides,
  };
}

function forumRule(overrides = {}) {
  return ruleKind("forum_content", {
    references: {
      categories: [],
      tags: [],
      missing_category_ids: [],
      missing_tag_ids: [],
    },
    ...overrides,
  });
}

function ruleKindOf(request) {
  const [, kind] = request.url.match(/content-restrictions\/([^/?]+)\.json/);
  return decodeURIComponent(kind);
}

acceptance("Admin - MCP content restrictions", function (needs) {
  let payload;
  let requests;

  needs.user({ admin: true });
  needs.settings({ tagging_enabled: true });

  needs.hooks.beforeEach(() => {
    requests = [];
    payload = {
      rule_kinds: [
        ruleKind("private_messages", {
          newly_disables: ["tool:discourse_send_pm"],
        }),
        forumRule(),
      ],
      orphans: [],
      private_message_scopes_overridden: false,
      primitive_titles: { "tool:discourse_send_pm": "Send a message" },
    };
  });

  needs.pretender((server, helper) => {
    server.get("/admin/mcp/content-restrictions.json", () =>
      helper.response(payload)
    );
    server.put("/admin/mcp/content-restrictions/:kind", (request) => {
      const kind = ruleKindOf(request);
      const { config } = JSON.parse(request.requestBody);
      requests.push({ method: "PUT", kind, config });
      payload = {
        ...payload,
        rule_kinds: payload.rule_kinds.map((entry) =>
          entry.name === kind
            ? { ...entry, active: true, config, newly_disables: [] }
            : entry
        ),
      };
      return helper.response(payload);
    });
    server.delete("/admin/mcp/content-restrictions/:kind", (request) => {
      const kind = ruleKindOf(request);
      requests.push({ method: "DELETE", kind });
      payload = {
        ...payload,
        orphans: payload.orphans.filter((orphan) => orphan.rule_kind !== kind),
        rule_kinds: payload.rule_kinds.map((entry) =>
          entry.name === kind
            ? { ...entry, active: false, config: null }
            : entry
        ),
      };
      return helper.response(204, "");
    });
  });

  test("shows a card per rule kind and explains the restrictions", async function (assert) {
    await visit("/admin/config/mcp/content-restrictions");

    assert
      .dom(".admin-mcp-content-restrictions__rule.--private-messages")
      .exists("the personal messages rule has its card");
    assert
      .dom(".admin-mcp-content-restrictions__rule.--forum-content")
      .exists("the topics and posts rule has its card");
    assert
      .dom(".admin-mcp-content-restrictions__help")
      .includesText(
        i18n("admin.config.mcp.content_restrictions.help.responders"),
        "the help warns that configured responders don't follow restrictions"
      );
    assert
      .dom(".admin-mcp-tabs__content-restrictions")
      .exists("the page has a tab");
  });

  test("confirms the tools that turn off before switching personal messages off", async function (assert) {
    await visit("/admin/config/mcp/content-restrictions");
    await click(".admin-mcp-content-restrictions__private-messages-toggle");

    assert
      .dom(".dialog-body")
      .includesText("Send a message", "the confirmation names the tool");

    await click(".dialog-footer .btn-default");

    assert.deepEqual(requests, [], "cancelling saves nothing");

    await click(".admin-mcp-content-restrictions__private-messages-toggle");
    await click(".dialog-footer .btn-primary");

    assert.deepEqual(
      requests,
      [{ method: "PUT", kind: "private_messages", config: {} }],
      "confirming stores the rule"
    );
    assert
      .dom(".admin-mcp-content-restrictions__private-messages-toggle")
      .hasAttribute("aria-checked", "false", "access is shown as off");

    await click(".admin-mcp-content-restrictions__private-messages-toggle");

    assert.deepEqual(
      requests.at(-1),
      { method: "DELETE", kind: "private_messages" },
      "switching access back on deletes the rule without a confirmation"
    );
  });

  test("saves the forum rule with tag names and keeps listed categories", async function (assert) {
    payload.rule_kinds[1] = forumRule({
      active: true,
      config: {
        allow: { mode: "all", category_ids: [], tag_ids: [] },
        deny: { category_ids: [], tag_ids: [7] },
      },
      references: {
        categories: [],
        tags: [{ id: 7, name: "legal-hold" }],
        missing_category_ids: [],
        missing_tag_ids: [],
      },
    });

    await visit("/admin/config/mcp/content-restrictions");
    await click(".admin-mcp-content-restrictions__save");

    assert.deepEqual(
      requests,
      [
        {
          method: "PUT",
          kind: "forum_content",
          config: {
            allow: { mode: "all", category_ids: [], tag_names: [] },
            deny: { category_ids: [], tag_names: ["legal-hold"] },
          },
        },
      ],
      "the stored tags are sent back by name"
    );
  });

  test("warns about listed categories and tags that no longer exist", async function (assert) {
    payload.rule_kinds[1] = forumRule({
      active: true,
      config: {
        allow: { mode: "all", category_ids: [], tag_ids: [] },
        deny: { category_ids: [404], tag_ids: [] },
      },
      references: {
        categories: [],
        tags: [],
        missing_category_ids: [404],
        missing_tag_ids: [],
      },
    });

    await visit("/admin/config/mcp/content-restrictions");

    assert
      .dom(".--forum-content .admin-mcp-content-restrictions__warning")
      .includesText(
        i18n(
          "admin.config.mcp.content_restrictions.forum_content.missing_targets"
        )
      );
  });

  test("lets an admin delete a rule whose kind is no longer known", async function (assert) {
    payload.orphans = [
      { rule_kind: "gone:rule", updated_at: "2026-11-25T10:00:00Z" },
    ];

    await visit("/admin/config/mcp/content-restrictions");

    assert
      .dom(".admin-mcp-content-restrictions__rule.--unknown")
      .includesText("gone:rule");

    await click(".--unknown .admin-mcp-content-restrictions__delete");

    assert.deepEqual(requests, [{ method: "DELETE", kind: "gone:rule" }]);
    assert
      .dom(".admin-mcp-content-restrictions__rule.--unknown")
      .doesNotExist("the deleted rule's card is gone");
  });

  test("renders the component a plugin registers for its rule kind", async function (assert) {
    withPluginApi((api) => {
      api.registerMcpContentRuleComponent("plugin-rule", PluginRuleCard);
    });
    payload.rule_kinds.push(
      ruleKind("plugin:rule", {
        provider: "plugin",
        admin_component_id: "plugin-rule",
      })
    );

    await visit("/admin/config/mcp/content-restrictions");

    assert.dom(".plugin-rule-card").hasText("plugin:rule");
  });
});
