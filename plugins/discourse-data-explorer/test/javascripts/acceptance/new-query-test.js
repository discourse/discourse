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
          sql: "-- [params]\n-- int :months_ago = 1\n\nWITH query_period AS\n(SELECT date_trunc('month', CURRENT_DATE) - INTERVAL ':months_ago months' AS period_start,\n                                                    date_trunc('month', CURRENT_DATE) - INTERVAL ':months_ago months' + INTERVAL '1 month' - INTERVAL '1 second' AS period_end)\nSELECT t.id AS topic_id,\n    t.category_id,\n    COUNT(p.id) AS reply_count\nFROM topics t\nJOIN posts p ON t.id = p.topic_id\nJOIN query_period qp ON p.created_at >= qp.period_start\nAND p.created_at <= qp.period_end\nWHERE t.archetype = 'regular'\nAND t.user_id > 0\nGROUP BY t.id\nORDER BY COUNT(p.id) DESC, t.score DESC\nLIMIT 100\n",
          name: "foo",
          description:
            "based on the number of replies, it accepts a ‘months_ago’ parameter, defaults to 1 to give results for the last calendar month.",
          param_info: [
            {
              identifier: "months_ago",
              type: "int",
              default: "1",
              nullable: false,
            },
          ],
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
          sql: "-- [params]\n-- int :months_ago = 1\n\nWITH query_period AS\n(SELECT date_trunc('month', CURRENT_DATE) - INTERVAL ':months_ago months' AS period_start,\n                                                    date_trunc('month', CURRENT_DATE) - INTERVAL ':months_ago months' + INTERVAL '1 month' - INTERVAL '1 second' AS period_end)\nSELECT t.id AS topic_id,\n    t.category_id,\n    COUNT(p.id) AS reply_count\nFROM topics t\nJOIN posts p ON t.id = p.topic_id\nJOIN query_period qp ON p.created_at >= qp.period_start\nAND p.created_at <= qp.period_end\nWHERE t.archetype = 'regular'\nAND t.user_id > 0\nGROUP BY t.id\nORDER BY COUNT(p.id) DESC, t.score DESC\nLIMIT 100\n",
          name: "foo",
          description:
            "based on the number of replies, it accepts a ‘months_ago’ parameter, defaults to 1 to give results for the last calendar month.",
          param_info: [
            {
              identifier: "months_ago",
              type: "int",
              default: "1",
              nullable: false,
            },
          ],
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

  test("creates a new query", async function (assert) {
    await visit("/admin/plugins/discourse-data-explorer/queries");

    // select new query button
    await click(".discourse-data-explorer-query-list button");
    await fillIn(".query-create input", "foo");
    // select create new query button
    await click(".query-create button");

    assert.strictEqual(
      currentURL(),
      "/admin/plugins/discourse-data-explorer/queries/-15"
    );
  });
});
