import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Data Explorer Plugin | New Query", function (needs) {
  needs.user();
  needs.settings({ data_explorer_enabled: true });

  needs.pretender((server, helper) => {
    server.get("/admin/plugins/discourse-data-explorer.json", () => {
      return helper.response({
        id: "discourse-data-explorer",
        name: "discourse-data-explorer",
        enabled: true,
        has_settings: true,
        humanized_name: "Data Explorer",
        is_discourse_owned: true,
        admin_route: {
          label: "explorer.title",
          location: "discourse-data-explorer",
          use_new_show_route: true,
        },
      });
    });

    server.get("/admin/plugins/discourse-data-explorer/groups.json", () => {
      return helper.response([]);
    });

    server.get("/admin/plugins/discourse-data-explorer/schema.json", () => {
      return helper.response({});
    });

    server.get("/admin/plugins/discourse-data-explorer/queries", () => {
      return helper.response({
        queries: [],
      });
    });

    server.post("/admin/plugins/discourse-data-explorer/queries", () => {
      return helper.response({
        query: {
          id: -15,
          sql: "SELECT 1",
          name: "foo",
          description: "a test query",
          param_info: [],
          created_at: "2021-02-05T16:42:45.572Z",
          username: "system",
          group_ids: [],
          last_run_at: "2021-02-08T15:37:49.188Z",
          hidden: false,
          user_id: -1,
        },
      });
    });

    server.get("/admin/plugins/discourse-data-explorer/queries/-15", () => {
      return helper.response({
        query: {
          id: -15,
          sql: "SELECT 1",
          name: "foo",
          description: "a test query",
          param_info: [],
          created_at: "2021-02-05T16:42:45.572Z",
          username: "system",
          group_ids: [],
          last_run_at: "2021-02-08T15:37:49.188Z",
          hidden: false,
          user_id: -1,
        },
      });
    });
  });

  test("navigates to new query page and creates a query", async function (assert) {
    await visit("/admin/plugins/discourse-data-explorer/queries");

    await click(".d-page-subheader .btn-primary");
    assert.strictEqual(
      currentURL(),
      "/admin/plugins/discourse-data-explorer/queries/new"
    );

    await fillIn(".query-new [data-name='name'] input", "foo");
    await fillIn(
      ".query-new [data-name='description'] textarea",
      "a test query"
    );
    await click(".query-new .btn-primary");

    assert.strictEqual(
      currentURL(),
      "/admin/plugins/discourse-data-explorer/queries/-15"
    );
  });
});
