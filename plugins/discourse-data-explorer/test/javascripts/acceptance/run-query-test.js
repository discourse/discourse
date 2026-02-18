import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("Data Explorer Plugin | Run Query", function (needs) {
  needs.user();
  needs.settings({ data_explorer_enabled: true });

  needs.hooks.beforeEach(() => {
    sinon.stub(window, "open");
  });

  needs.hooks.afterEach(() => {
    window.open.restore();
  });

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
      return helper.response([
        {
          id: 1,
          name: "admins",
        },
        {
          id: 2,
          name: "moderators",
        },
        {
          id: 3,
          name: "staff",
        },
        {
          id: 0,
          name: "everyone",
        },
        {
          id: 10,
          name: "trust_level_0",
        },
        {
          id: 11,
          name: "trust_level_1",
        },
        {
          id: 12,
          name: "trust_level_2",
        },
        {
          id: 13,
          name: "trust_level_3",
        },
        {
          id: 14,
          name: "trust_level_4",
        },
      ]);
    });

    server.get("/admin/plugins/discourse-data-explorer/schema.json", () => {
      return helper.response({
        anonymous_users: [
          {
            column_name: "id",
            data_type: "serial",
            primary: true,
          },
          {
            column_name: "user_id",
            data_type: "integer",
            fkey_info: "users",
          },
          {
            column_name: "master_user_id",
            data_type: "integer",
            fkey_info: "users",
          },
          {
            column_name: "active",
            data_type: "boolean",
          },
          {
            column_name: "created_at",
            data_type: "timestamp",
          },
          {
            column_name: "updated_at",
            data_type: "timestamp",
          },
        ],
      });
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
            id: 2,
            name: "What about 0?",
            description: "",
            username: "system",
            group_ids: [],
            last_run_at: "2023-05-04T22:16:23.858Z",
            user_id: 1,
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

    server.get("/admin/plugins/discourse-data-explorer/queries/2", () => {
      return helper.response({
        query: {
          id: 2,
          sql: 'SELECT 0 zero, null "null", false "false"',
          name: "What about 0?",
          description: "",
          param_info: [],
          created_at: "2023-05-04T22:16:06.007Z",
          username: "system",
          group_ids: [],
          last_run_at: "2023-05-04T22:16:23.858Z",
          hidden: false,
          user_id: 1,
        },
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

    server.post("/admin/plugins/discourse-data-explorer/queries/2/run", () => {
      return helper.response({
        success: true,
        errors: [],
        duration: 1.0,
        result_count: 1,
        params: {},
        columns: ["zero", "null", "false"],
        default_limit: 1000,
        relations: {},
        colrender: {},
        rows: [[0, null, false]],
      });
    });

    server.get("/session/csrf.json", function () {
      return helper.response({
        csrf: "mgk906YLagHo2gOgM1ddYjAN4hQolBdJCqlY6jYzAYs= ",
      });
    });

    server.get("/g/testgroup/reports/2", () => {
      return helper.response({
        query: {
          id: 2,
          sql: 'SELECT 0 zero, null "null", false "false"',
          name: "Group Test Query",
          description: "Test query for group reports",
          param_info: [],
          created_at: "2023-05-04T22:16:06.007Z",
          username: "system",
          group_ids: [1],
          last_run_at: "2023-05-04T22:16:23.858Z",
          hidden: false,
          user_id: 1,
        },
        query_group: {
          id: 1,
          group_id: 1,
          query_id: 2,
        },
      });
    });

    server.post("/g/testgroup/reports/2/run", () => {
      return helper.response({
        success: true,
        errors: [],
        duration: 1.0,
        result_count: 1,
        params: {},
        columns: ["zero", "null", "false"],
        default_limit: 1000,
        relations: {},
        colrender: {},
        rows: [[0, null, false]],
      });
    });

    server.get("/groups/testgroup.json", () => {
      return helper.response({
        group: {
          id: 1,
          name: "testgroup",
        },
      });
    });
  });

  test("runs query and renders data and a chart", async function (assert) {
    await visit("/admin/plugins/discourse-data-explorer/queries/-6");

    assert
      .dom("div.name h1")
      .hasText("Top 100 Likers", "the query name was rendered");

    assert.dom("div.query-edit").exists("the query code was rendered");

    assert
      .dom("form.query-run button span")
      .hasText(i18n("explorer.run"), "the run button was rendered");

    await click("form.query-run button");

    assert
      .dom("div.query-results table tbody tr")
      .exists({ count: 2 }, "the table with query results was rendered");

    assert
      .dom("div.result-info button:nth-child(3) span")
      .hasText(i18n("explorer.show_graph"), "the chart button was rendered");

    await click("div.result-info button:nth-child(3)");

    assert.dom("canvas").exists("the chart was rendered");
  });

  test("runs query and is able to download the results", async function (assert) {
    await visit("/admin/plugins/discourse-data-explorer/queries/-6");

    await click("form.query-run button");

    const createElement = document.createElement.bind(document);
    const appendChild = document.body.appendChild.bind(document.body);
    const removeChild = document.body.removeChild.bind(document.body);

    const finishedForm = sinon.promise();

    let formElement;

    const formStub = sinon
      .stub(document, "createElement")
      .callsFake((tagName) => {
        if (tagName === "form") {
          formElement = {
            fakeForm: true,
            setAttribute: sinon.stub(),
            appendChild: sinon.stub(),
            submit: sinon.stub().callsFake(finishedForm.resolve),
          };

          return formElement;
        }

        return createElement(tagName);
      });

    const appendChildStub = sinon
      .stub(document.body, "appendChild")
      .callsFake((el) => {
        if (!el.fakeForm) {
          return appendChild(el);
        }
      });

    const removeChildStub = sinon
      .stub(document.body, "removeChild")
      .callsFake((el) => {
        if (!el.fakeForm) {
          return removeChild(el);
        }
      });

    await click("div.result-info button:nth-child(1)");

    await finishedForm;

    formStub.restore();
    appendChildStub.restore();
    removeChildStub.restore();

    assert.true(window.open.called, "window.open was called for downloading");
    assert.true(formStub.called, "form was created for downloading");
    assert.true(
      formElement.submit.called,
      "form was submitted for downloading"
    );

    assert.true(
      formElement.setAttribute.calledWith("action"),
      "form action attribute was set"
    );
    assert.true(
      formElement.setAttribute.calledWith("method", "post"),
      "form method attribute was set to POST"
    );
  });

  test("runs query and renders 0, false, and NULL values correctly", async function (assert) {
    await visit("/admin/plugins/discourse-data-explorer/queries/2");

    assert
      .dom("div.name h1 span")
      .hasText("What about 0?", "the query name was rendered");

    assert
      .dom("form.query-run button span")
      .hasText(i18n("explorer.run"), "the run button was rendered");

    await click("form.query-run button");

    assert
      .dom("div.query-results tbody td:nth-child(1)")
      .hasText("0", "renders '0' values");

    assert
      .dom("div.query-results tbody td:nth-child(2)")
      .hasText("NULL", "renders 'NULL' values");

    assert
      .dom("div.query-results tbody td:nth-child(3)")
      .hasText("false", "renders 'false' values");
  });

  test("automatically runs query when run query parameter is present", async function (assert) {
    await visit("/admin/plugins/discourse-data-explorer/queries/2?run");

    assert
      .dom("div.query-results table tbody tr")
      .exists({ count: 1 }, "query results should be displayed");
  });

  test("automatically runs query when run query parameter is present on group report route", async function (assert) {
    await visit("/g/testgroup/reports/2?run=1");

    assert.dom("div.query-results").exists("query results should be displayed");
  });
});
