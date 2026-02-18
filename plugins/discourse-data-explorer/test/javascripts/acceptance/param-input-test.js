import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import Category from "discourse/models/category";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

async function runQuery() {
  await click("form.query-run button");
}

acceptance("Data Explorer Plugin | Param Input", function (needs) {
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
        queries: [
          {
            id: -6,
            name: "Top 100 Likers",
            description:
              "returns the top 100 likers for a given monthly period ordered by like_count. It accepts a ‘months_ago’ parameter, defaults to 1 to give results for the last calendar month.",
            username: "system",
            group_ids: [],
            last_run_at: "2021-02-11T08:29:59.337Z",
            user_id: -1,
          },
          {
            id: -7,
            name: "Invalid Query",
            description: "",
            username: "bianca",
            group_ids: [],
            last_run_at: "2022-01-14T16:47:34.244Z",
            user_id: 1,
          },
          {
            id: 3,
            name: "Params test",
            description: "test for params.",
            username: "system",
            group_ids: [41],
            last_run_at: "2021-02-11T08:29:59.337Z",
            user_id: -1,
          },
        ],
      });
    });

    server.get("/admin/plugins/discourse-data-explorer/queries/-6", () => {
      return helper.response({
        query: {
          id: -6,
          sql: "-- [params]\n-- int :months_ago = 1\n\nWITH query_period AS (\n    SELECT\n        date_trunc('month', CURRENT_DATE) - INTERVAL ':months_ago months' as period_start,\n        date_trunc('month', CURRENT_DATE) - INTERVAL ':months_ago months' + INTERVAL '1 month' - INTERVAL '1 second' as period_end\n        )\n\n    SELECT\n        ua.user_id,\n        count(1) AS like_count\n    FROM user_actions ua\n    INNER JOIN query_period qp\n    ON ua.created_at >= qp.period_start\n    AND ua.created_at <= qp.period_end\n    WHERE ua.action_type = 1\n    GROUP BY ua.user_id\n    ORDER BY like_count DESC\n    LIMIT 100\n",
          name: "Top 100 Likers",
          description:
            "returns the top 100 likers for a given monthly period ordered by like_count. It accepts a ‘months_ago’ parameter, defaults to 1 to give results for the last calendar month.",
          param_info: [
            {
              identifier: "months_ago",
              type: "int",
              default: "1",
              nullable: false,
            },
          ],
          created_at: "2021-02-02T12:21:11.449Z",
          username: "system",
          group_ids: [],
          last_run_at: "2021-02-11T08:29:59.337Z",
          hidden: false,
          user_id: -1,
        },
      });
    });

    server.put("/admin/plugins/discourse-data-explorer/queries/-6", () => {
      return helper.response({
        success: true,
        errors: [],
        duration: 27.5,
        result_count: 2,
        columns: ["user_id", "like_count"],
        default_limit: 1000,
        relations: {
          user: [
            {
              id: -2,
              username: "discobot",
              name: null,
              avatar_template: "/user_avatar/localhost/discobot/{size}/2_2.png",
            },
            {
              id: 2,
              username: "andrey1",
              name: null,
              avatar_template:
                "/letter_avatar_proxy/v4/letter/a/c0e974/{size}.png",
            },
          ],
        },
        colrender: {
          0: "user",
        },
        rows: [
          [-2, 2],
          [2, 2],
        ],
      });
    });

    server.post("/admin/plugins/discourse-data-explorer/queries/-6/run", () => {
      return helper.response({
        success: true,
        errors: [],
        duration: 27.5,
        result_count: 2,
        params: { months_ago: "1" },
        columns: ["user_id", "like_count"],
        default_limit: 1000,
        relations: {
          user: [
            {
              id: -2,
              username: "discobot",
              name: null,
              avatar_template: "/user_avatar/localhost/discobot/{size}/2_2.png",
            },
            {
              id: 2,
              username: "andrey1",
              name: null,
              avatar_template:
                "/letter_avatar_proxy/v4/letter/a/c0e974/{size}.png",
            },
          ],
        },
        colrender: {
          0: "user",
        },
        rows: [
          [-2, 2],
          [2, 2],
        ],
      });
    });

    server.get("/g/discourse/reports/-8", () => {
      return helper.response({
        query: {
          id: -8,
          sql: "-- [params]\n-- int :months_ago = 1\n\nWITH query_period AS (\n    SELECT\n        date_trunc('month', CURRENT_DATE) - INTERVAL ':months_ago months' as period_start,\n        date_trunc('month', CURRENT_DATE) - INTERVAL ':months_ago months' + INTERVAL '1 month' - INTERVAL '1 second' as period_end\n        )\n\n    SELECT\n        ua.user_id,\n        count(1) AS like_count\n    FROM user_actions ua\n    INNER JOIN query_period qp\n    ON ua.created_at >= qp.period_start\n    AND ua.created_at <= qp.period_end\n    WHERE ua.action_type = 1\n    GROUP BY ua.user_id\n    ORDER BY like_count DESC\n    LIMIT 100\n",
          name: "Top 100 Likers Report",
          description:
            "returns the top 100 likers for a given monthly period ordered by like_count. It accepts a ‘months_ago’ parameter, defaults to 1 to give results for the last calendar month.",
          param_info: [
            {
              identifier: "months_ago",
              type: "int",
              default: "1",
              nullable: false,
            },
          ],
          created_at: "2021-02-02T12:21:11.449Z",
          username: "system",
          group_ids: [41],
          last_run_at: "2021-02-11T08:29:59.337Z",
          hidden: false,
          user_id: -1,
        },
      });
    });

    server.get("/admin/plugins/discourse-data-explorer/queries/-7", () => {
      return helper.response({
        query: {
          id: -7,
          sql: "-- [params]\n-- user_id :user\n\nSELECT :user_id\n\n",
          name: "Invalid Query",
          description: "",
          param_info: [
            {
              identifier: "user",
              type: "user_id",
              default: null,
              nullable: false,
            },
          ],
          created_at: "2022-01-14T16:40:05.458Z",
          username: "bianca",
          group_ids: [],
          last_run_at: "2022-01-14T16:47:34.244Z",
          hidden: false,
          user_id: 1,
        },
      });
    });

    server.post("/admin/plugins/discourse-data-explorer/queries/-7/run", () => {
      return helper.response({
        success: true,
        errors: [],
        duration: 27.5,
        params: { user_id: "null" },
        columns: ["user_id"],
        default_limit: 1000,
        relations: {
          user: [
            {
              id: 2,
              username: "andrey1",
              name: null,
              avatar_template:
                "/letter_avatar_proxy/v4/letter/a/c0e974/{size}.png",
            },
          ],
        },
        colrender: {
          0: "user",
        },
        rows: [],
      });
    });

    server.post("/g/discourse/reports/-8/run", () => {
      return helper.response({
        success: true,
        errors: [],
        duration: 27.5,
        result_count: 2,
        params: { months_ago: "1" },
        columns: ["user_id", "like_count"],
        default_limit: 1000,
        relations: {
          user: [
            {
              id: -2,
              username: "discobot",
              name: null,
              avatar_template: "/user_avatar/localhost/discobot/{size}/2_2.png",
            },
            {
              id: 2,
              username: "andrey1",
              name: null,
              avatar_template:
                "/letter_avatar_proxy/v4/letter/a/c0e974/{size}.png",
            },
          ],
        },
        colrender: {
          0: "user",
        },
        rows: [
          [-2, 2],
          [2, 2],
        ],
      });
    });

    server.get("/admin/plugins/discourse-data-explorer/queries/3", () => {
      return helper.response({
        query: {
          id: 3,
          sql: "SELECT 1",
          name: "Params test",
          description: "test for params.",
          param_info: [],
          created_at: "2021-02-02T12:21:11.449Z",
          username: "system",
          group_ids: [41],
          last_run_at: "2021-02-11T08:29:59.337Z",
          hidden: false,
          user_id: -1,
        },
      });
    });

    server.put("/admin/plugins/discourse-data-explorer/queries/3", () => {
      return helper.response({
        query: {
          id: 3,
          sql: "-- [params]\n-- int :months_ago = 1\n\nSELECT 1",
          name: "Params test",
          description: "test for params.",
          param_info: [
            {
              identifier: "months_ago",
              type: "int",
              default: "1",
              nullable: false,
            },
          ],
          created_at: "2021-02-02T12:21:11.449Z",
          username: "system",
          group_ids: [41],
          last_run_at: "2021-02-11T08:29:59.337Z",
          hidden: false,
          user_id: -1,
        },
      });
    });

    server.get("/admin/plugins/discourse-data-explorer/queries/4", () => {
      return helper.response({
        query: {
          id: 4,
          sql: "-- [params]\n-- null category_id :category\n\nSELECT 1",
          name: "Params test - category_id chooser",
          description: "Test for category_id param.",
          param_info: [
            {
              identifier: "category",
              type: "category_id",
              default: null,
              nullable: true,
            },
          ],
          created_at: "2025-06-03T09:05:59.337Z",
          username: "system",
          group_ids: [],
          last_run_at: "2025-06-03T09:05:59.337Z",
          hidden: false,
          category_id: null,
        },
      });
    });

    server.post("/admin/plugins/discourse-data-explorer/queries/4/run", () => {
      return helper.response({});
    });
  });

  function getSearchParam(param) {
    const searchParams = new URLSearchParams(currentURL().split("?")[1]);
    return JSON.parse(searchParams.get("params"))[param];
  }

  test("puts params for the query into the url", async function (assert) {
    await visit("/admin/plugins/discourse-data-explorer/queries/-6");
    const monthsAgoValue = "2";
    await fillIn(".query-params input", monthsAgoValue);
    await runQuery();

    assert.strictEqual(getSearchParam("months_ago"), monthsAgoValue);
  });

  test("puts params for the query into the url for group reports", async function (assert) {
    await visit("/g/discourse/reports/-8");
    const monthsAgoValue = "2";
    await fillIn(".query-params input", monthsAgoValue);
    await runQuery();

    assert.strictEqual(getSearchParam("months_ago"), monthsAgoValue);
  });

  test("loads the page if one of the parameter is null", async function (assert) {
    await visit(
      '/admin/plugins/discourse-data-explorer/queries/-7?params={"user":null}'
    );
    assert.dom(".query-params .user-chooser").exists();
    assert.dom(".query-run .btn.btn-primary").exists();
  });

  test("loads the page if one of the parameter is null for group reports", async function (assert) {
    await visit('/g/discourse/reports/-8?params={"months_ago":null}');
    assert.dom(".query-params input").exists();
    assert.dom(".query-run .btn.btn-primary").exists();
  });

  test("applies params when running a report", async function (assert) {
    await visit("/g/discourse/reports/-8");
    const monthsAgoValue = "2";
    await fillIn(".query-params input", monthsAgoValue);
    await runQuery();
    assert.dom(".query-params input").hasValue(monthsAgoValue);
  });

  test("creates input boxes if has parameters when save", async function (assert) {
    await visit("/admin/plugins/discourse-data-explorer/queries/3");
    assert.dom(".query-params input").doesNotExist();
    await click(".query-edit .btn-edit-query");
    await fillIn(
      ".query-editor .ace_text-input",
      "-- [params]\n-- int :months_ago = 1\n\nSELECT 1"
    );
    await click(".query-editor .ace_text-input"); // enables `Save Changes` button
    await click(".query-edit .btn-save-query");
    assert.dom(".query-params input").exists();
  });

  test("nullable category_id param", async function (assert) {
    await visit("/admin/plugins/discourse-data-explorer/queries/4");
    const catChooser = selectKit(".category-chooser");

    assert.strictEqual(catChooser.header().value(), null);

    await runQuery();

    assert.strictEqual(getSearchParam("category"), "");

    const category = Category.findById(6);
    await catChooser.expand();
    await catChooser.selectRowByValue(category.id);

    assert.strictEqual(catChooser.header().label(), category.name);

    await runQuery();

    assert.strictEqual(
      getSearchParam("category"),
      category.id.toString(),
      "it updates the URL with the selected category id"
    );

    await catChooser.expand();
    await catChooser.selectRowByIndex(0);
    await runQuery();

    assert.strictEqual(
      getSearchParam("category"),
      undefined,
      "it removes the category id from the URL when selecting the first row (null value)"
    );
  });
});
