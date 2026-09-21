import { click, currentURL, visit, waitFor } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import packNodeTypes from "../fixtures/node-pack-node-types";
import { nodePackDetail } from "../fixtures/node-packs";

acceptance("Discourse Workflows | Node packs", function (needs) {
  needs.user({ admin: true });

  needs.pretender((server, helper) => {
    server.get("/admin/plugins/discourse-workflows.json", () =>
      helper.response({
        id: "discourse-workflows",
        name: "discourse-workflows",
        humanized_name: "Discourse Workflows",
        enabled: true,
        admin_route: { use_new_show_route: true },
      })
    );
    server.get("/admin/plugins/discourse-workflows/workflows/1.json", () =>
      helper.response({
        workflow: {
          id: 1,
          name: "Demo workflow",
          nodes: [],
          connections: [],
          sticky_notes: [],
          settings: {},
          static_data: {},
          pin_data: {},
        },
      })
    );
    server.get("/admin/plugins/discourse-workflows/stats/1.json", () =>
      helper.response({})
    );
    server.get("/admin/plugins/discourse-workflows/workflow-tags.json", () =>
      helper.response({ workflow_tags: [] })
    );
    server.get("/admin/plugins/discourse-workflows/node-types.json", () =>
      helper.response({
        node_types: packNodeTypes,
        credential_types: [],
        expression_context: {},
      })
    );
    server.get("/admin/plugins/discourse-workflows/node-packs/7.json", () =>
      helper.response({ node_pack: nodePackDetail })
    );
    server.get("/admin/plugins/discourse-workflows/node-packs.json", () =>
      helper.response({ node_packs: [], meta: { total_rows: 0 } })
    );
  });

  test("keeps Node packs active on the list and detail pages", async function (assert) {
    const tab =
      '.admin-plugin-config-page__top-nav-item a[href="/admin/plugins/discourse-workflows/node-packs"]';

    await visit("/admin/plugins/discourse-workflows/node-packs");
    assert.dom(tab).hasClass("active", "Node packs is active on the list");

    await visit("/admin/plugins/discourse-workflows/node-packs/7");
    assert
      .dom(tab)
      .hasClass("active", "Node packs remains active on a pack detail page");
  });

  test("the workflow palette opens a reusable import URL", async function (assert) {
    await visit("/admin/plugins/discourse-workflows/workflows/1");
    await waitFor(".workflows-canvas__empty-state-trigger");
    await click(".workflows-canvas__empty-state-trigger:first-child");
    await click(".workflows-node-panel__footer a:last-child");

    assert
      .dom(".workflows-node-pack-import")
      .exists("the palette link opens the import modal");
    assert.strictEqual(
      currentURL(),
      "/admin/plugins/discourse-workflows/node-packs",
      "the one-shot import query parameter is consumed"
    );

    await click(".workflows-node-pack-import .modal-close");
    await visit("/admin/plugins/discourse-workflows/node-packs?import=1");

    assert
      .dom(".workflows-node-pack-import")
      .exists("the same-route import URL can open the modal again");
    assert.strictEqual(
      currentURL(),
      "/admin/plugins/discourse-workflows/node-packs",
      "the repeated query parameter is consumed"
    );
  });
});
