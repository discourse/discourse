import {
  click,
  currentURL,
  fillIn,
  find,
  settled,
  visit,
  waitUntil,
} from "@ember/test-helpers";
import { test } from "qunit";
import pretender from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("List Queries", function (needs) {
  needs.user();
  needs.settings({ data_explorer_enabled: true });

  let lastQueryParams;
  let handleQueries;

  needs.hooks.beforeEach(() => {
    lastQueryParams = null;
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
      return helper.response([]);
    });

    server.get("/admin/plugins/discourse-data-explorer/schema.json", () => {
      return helper.response({});
    });

    server.get(
      "/admin/plugins/discourse-data-explorer/queries/tags.json",
      () => {
        return helper.response(["default", "staff"]);
      }
    );

    server.get("/admin/plugins/discourse-data-explorer/queries/1", () => {
      return helper.response({
        query: {
          id: 1,
          name: "Staff activity",
          description: "Shows staff activity.",
          sql: "SELECT 1",
          param_info: [],
          group_ids: [],
          tags: ["staff"],
          user_id: 1,
          is_default: false,
        },
      });
    });

    handleQueries = (request) => {
      lastQueryParams = request.queryParams;
      const queries = [
        {
          id: -6,
          name: "Top 100 Likers",
          description:
            "returns the top 100 likers for a given monthly period ordered by like_count. It accepts a ‘months_ago’ parameter, defaults to 1 to give results for the last calendar month.",
          username: "system",
          group_ids: [],
          last_run_at: "2021-02-11T08:29:59.337Z",
          user_id: -1,
          tags: ["default", "staff"],
        },
        {
          id: -5,
          name: "Top 100 Active Topics",
          description:
            "based on the number of replies, it accepts a ‘months_ago’ parameter, defaults to 1 to give results for the last calendar month.",
          username: "system",
          group_ids: [],
          last_run_at: "2021-02-08T15:37:49.188Z",
          user_id: -1,
          tags: ["default"],
        },
        {
          id: 1,
          name: "Staff activity",
          description: "Shows staff activity.",
          username: "admin",
          group_ids: [],
          last_run_at: "2021-02-07T15:37:49.188Z",
          user_id: 1,
          tags: ["staff"],
        },
      ];
      const tags = request.queryParams.tags?.split(",") ?? [];
      const filter = request.queryParams.filter?.toLowerCase();
      const filteredQueries = queries.filter((query) => {
        return (
          tags.every((tag) => query.tags.includes(tag)) &&
          (!filter || query.name.toLowerCase().includes(filter))
        );
      });

      return helper.response({
        queries: filteredQueries,
        total_rows_queries: filteredQueries.length,
        extras: { tags: ["default", "staff"] },
      });
    };

    server.get("/admin/plugins/discourse-data-explorer/queries", handleQueries);
    server.get(
      "/admin/plugins/discourse-data-explorer/queries.json",
      handleQueries
    );
  });

  test("renders the page with the list of queries", async function (assert) {
    await visit("/admin/plugins/discourse-data-explorer/queries");

    assert
      .dom(".d-filter-controls__input")
      .hasAttribute(
        "placeholder",
        i18n("explorer.search_placeholder"),
        "the search box was rendered"
      );

    assert
      .dom(".d-page-subheader .btn-primary")
      .exists("the add query button was rendered");

    assert
      .dom(".d-page-subheader .d-page-action-wrapped-button")
      .hasText(i18n("explorer.import.label"), "the import button was rendered");

    assert
      .dom("div.container table.recent-queries tbody tr")
      .exists({ count: 3 }, "the list of queries was rendered");

    assert
      .dom("div.container table.recent-queries tbody tr:nth-child(1) td")
      .hasText(/^\s*Top 100 Likers/, "The first query was rendered");

    assert
      .dom("div.container table.recent-queries tbody tr:nth-child(2) td")
      .hasText(/^\s*Top 100 Active Topics/, "The second query was rendered");

    assert
      .dom(".query-badge")
      .doesNotExist("default queries do not render a separate badge");

    assert
      .dom(".query-row:first-child .query-tags .d-table-badge")
      .exists({ count: 2 }, "the query tags appear below its description");

    assert
      .dom(".query-tag-filter .d-multi-select-trigger__label")
      .hasText(
        i18n("explorer.filter_by_tag"),
        "the tag filter shows its placeholder initially"
      );
  });

  test("filters by multiple tags", async function (assert) {
    await visit("/admin/plugins/discourse-data-explorer/queries");

    await click(".query-tag-filter.d-multi-select-trigger");
    await click(".d-multi-select__result:first-child");

    assert
      .dom(".query-tag-filter .d-multi-select-trigger__selection-label")
      .hasText("default", "the selected default tag is displayed in lowercase");

    assert
      .dom("div.container table.recent-queries tbody tr")
      .exists({ count: 2 }, "only default queries are shown");

    await click(".d-multi-select__result:first-child");

    assert
      .dom(".query-tag-filter .d-multi-select-trigger__selected-item")
      .exists({ count: 2 }, "both selected tags remain visible");
    assert.strictEqual(lastQueryParams.tags, "default,staff");
    assert.strictEqual(
      new URLSearchParams(currentURL().split("?")[1]).get("tags"),
      "default,staff",
      "the selected tags are reflected in the URL"
    );
    assert
      .dom("div.container table.recent-queries tbody tr td")
      .hasText(/^\s*Top 100 Likers/, "only queries with both tags are shown");
  });

  test("filters by tags from the URL", async function (assert) {
    await visit(
      "/admin/plugins/discourse-data-explorer/queries?tags=default,staff"
    );

    assert.strictEqual(lastQueryParams.tags, "default,staff");
    assert
      .dom(".query-tag-filter .d-multi-select-trigger__selected-item")
      .exists({ count: 2 }, "both URL tags are selected");
    assert
      .dom(".recent-queries tbody tr")
      .exists({ count: 1 }, "only the query with both tags is shown");

    await fillIn(".d-filter-controls__input", "likers");
    assert.strictEqual(lastQueryParams.tags, "default,staff");
    assert.strictEqual(lastQueryParams.filter, "likers");
  });

  test("filters by clicking a query tag", async function (assert) {
    await visit("/admin/plugins/discourse-data-explorer/queries");
    await click(".query-row:first-child .query-tags .d-table-badge:last-child");

    assert.strictEqual(lastQueryParams.tags, "staff");
    assert
      .dom(".recent-queries tbody tr")
      .exists({ count: 2 }, "only queries with the clicked tag are shown");
  });

  test("keeps tag and text filters when returning from a query", async function (assert) {
    await visit("/admin/plugins/discourse-data-explorer/queries");

    await click(".query-tag-filter.d-multi-select-trigger");
    await click(".d-multi-select__result:nth-child(2)");
    await fillIn(".d-filter-controls__input", "activity");

    await click(".d-table__overview-link");
    await click(".back-button");

    assert.strictEqual(
      lastQueryParams.tags,
      "staff",
      "the tag is sent on return"
    );
    assert.strictEqual(
      lastQueryParams.filter,
      "activity",
      "the text search is sent on return"
    );
    assert.strictEqual(
      new URLSearchParams(currentURL().split("?")[1]).get("tags"),
      "staff",
      "the tag remains in the URL on return"
    );
    assert
      .dom(".query-tag-filter .d-multi-select-trigger__selection-label")
      .hasText("staff", "the selected tag remains visible");
    assert
      .dom(".d-filter-controls__input")
      .hasValue("activity", "the text search remains visible");
    assert
      .dom("div.container table.recent-queries tbody tr")
      .exists({ count: 1 }, "the returned list still applies both filters");
    assert
      .dom("div.container table.recent-queries tbody tr td")
      .hasText(/^\s*Staff activity/, "the matching query remains visible");
  });

  test("ignores an older tag-filter response that finishes last", async function (assert) {
    await visit("/admin/plugins/discourse-data-explorer/queries");

    const requests = [];
    pretender.get(
      "/admin/plugins/discourse-data-explorer/queries.json",
      (request) => {
        requests.push(request);
        return handleQueries(request);
      },
      true
    );

    const controller = this.owner.lookup(
      "controller:adminPlugins.show.explorer.index"
    );
    controller.onTagFilterChange([{ id: "default", name: "default" }]);
    controller.onTagFilterChange([{ id: "staff", name: "staff" }]);

    await waitUntil(() => requests.length === 2);
    pretender.resolve(requests[1]);
    await waitUntil(() =>
      find(".recent-queries tbody tr:last-child td")?.textContent.includes(
        "Staff activity"
      )
    );
    pretender.resolve(requests[0]);
    await settled();

    assert
      .dom(".recent-queries tbody tr:last-child td")
      .hasText(
        /^\s*Staff activity/,
        "the latest filter results remain visible"
      );
  });
});
