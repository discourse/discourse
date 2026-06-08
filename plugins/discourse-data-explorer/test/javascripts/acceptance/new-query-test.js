import { click, currentURL, fillIn, settled, visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  publishToMessageBus,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("New Query", function (needs) {
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
      return helper.response({
        topics: [
          {
            column_name: "id",
            data_type: "serial",
            primary: true,
          },
        ],
      });
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

  test("renders the manual create form and transitions on submit", async function (assert) {
    await visit("/admin/plugins/discourse-data-explorer/queries");

    await click(".d-page-subheader .btn-primary");
    assert.strictEqual(
      currentURL(),
      "/admin/plugins/discourse-data-explorer/queries/new"
    );

    assert
      .dom(".query-new__manual-form .right-panel .schema")
      .exists("schema sidebar renders");
    assert
      .dom(".query-new__manual-form .editor-panel .ace-wrapper")
      .exists("SQL editor renders alongside the schema sidebar");

    await fillIn(".query-new__manual-form [data-name='name'] input", "foo");
    await fillIn(
      ".query-new__manual-form [data-name='description'] textarea",
      "a test query"
    );
    await click(".query-new__manual-form .btn-primary");

    assert.strictEqual(
      currentURL(),
      "/admin/plugins/discourse-data-explorer/queries/-15"
    );
  });
});

acceptance("New Query - AI", function (needs) {
  needs.user();
  needs.settings({
    data_explorer_enabled: true,
    data_explorer_ai_queries_enabled: true,
  });

  const GENERATION_ID = "test-generation";

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

    server.get("/admin/plugins/discourse-data-explorer/groups.json", () =>
      helper.response([])
    );
    server.get("/admin/plugins/discourse-data-explorer/schema.json", () =>
      helper.response({ topics: [] })
    );
    server.get("/admin/plugins/discourse-data-explorer/queries", () =>
      helper.response({ queries: [] })
    );

    server.post(
      "/admin/plugins/discourse-data-explorer/queries/generate.json",
      () =>
        helper.response({ generation_id: GENERATION_ID, status: "generating" })
    );

    server.post(
      "/admin/plugins/discourse-data-explorer/queries/preview.json",
      () =>
        helper.response({
          success: true,
          errors: [],
          colrender: [],
          result_count: 1,
          columns: ["my_value"],
          rows: [[23]],
          duration: 1.2,
          default_limit: 1000,
        })
    );

    server.post("/admin/plugins/discourse-data-explorer/queries", () =>
      helper.response({
        query: {
          id: -15,
          sql: "SELECT 23 AS my_value",
          name: "Generated",
          description: "",
          param_info: [],
          group_ids: [],
          hidden: false,
          user_id: -1,
        },
      })
    );

    server.get("/admin/plugins/discourse-data-explorer/queries/-15", () =>
      helper.response({
        query: {
          id: -15,
          sql: "SELECT 23 AS my_value",
          name: "Generated",
          description: "",
          param_info: [],
          group_ids: [],
          hidden: false,
          user_id: -1,
        },
      })
    );

    server.post("/admin/plugins/discourse-data-explorer/queries/-15/run", () =>
      helper.response({
        success: true,
        errors: [],
        colrender: [],
        result_count: 1,
        columns: ["my_value"],
        rows: [[23]],
        duration: 1.2,
        default_limit: 1000,
      })
    );
  });

  async function generate(prompt) {
    await visit("/admin/plugins/discourse-data-explorer/queries/new");
    await fillIn(".query-new__ai-textarea", prompt);
    await click(".query-new__generate-btn");
    await publishToMessageBus(
      `/discourse-data-explorer/queries/ai-generation/${GENERATION_ID}`,
      {
        generation_id: GENERATION_ID,
        status: "complete",
        sql: "SELECT 23 AS my_value",
        name: "Generated",
        description: "",
      }
    );
    await settled();
  }

  test("save query is the primary action and the result is shown first", async function (assert) {
    await generate("show me a value");

    assert
      .dom(".query-new__save-btn.btn-primary")
      .exists("the save query button gets the primary treatment");
    assert
      .dom(".query-new__run-btn")
      .exists("a run button is available before saving");
    assert
      .dom(".query-results-modes")
      .exists("a chart/table/sql segmented control is shown");
    assert
      .dom(".query-new__result-bar .query-new__result-about")
      .hasText(
        /result/,
        "the result count sits on the same line as the toggle"
      );
    assert
      .dom(".query-new__preview .query-results-table-wrapper")
      .exists("the result is run and shown first, not the SQL");

    await click(".query-results-modes input[value='sql']");

    assert
      .dom(".query-new__sql-editor .ace-wrapper")
      .exists("the SQL is available behind its own tab");
  });

  test("saving transitions to the edit page and runs the query", async function (assert) {
    await generate("show me a value");

    await click(".query-new__save-btn");

    assert.true(
      currentURL().startsWith(
        "/admin/plugins/discourse-data-explorer/queries/-15"
      ),
      "transitions to the saved query"
    );
    assert.true(
      currentURL().includes("run=true"),
      "carries the auto-run flag so the query runs immediately"
    );
  });
});
