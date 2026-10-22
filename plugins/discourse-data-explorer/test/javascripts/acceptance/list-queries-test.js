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
import { JSON_API_VERSION } from "discourse/data/handlers/json-api";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

const INCLUDED = [
  {
    type: "users",
    id: "-1",
    attributes: {
      username: "system",
      avatarTemplate: "/images/discourse-logo-sketch-small.png",
    },
  },
  {
    type: "users",
    id: "1",
    attributes: {
      username: "admin",
      avatarTemplate: "/letter_avatar_proxy/v4/letter/a/{size}.png",
    },
  },
  { type: "groups", id: "41", attributes: { name: "analysts" } },
];

function toDocument(queries, next = null) {
  return {
    data: queries.map(({ id, userId, groupIds, groupsLinks, ...attrs }) => ({
      type: "queries",
      id: String(id),
      attributes: attrs,
      relationships: {
        user: { data: { type: "users", id: String(userId) } },
        groups: {
          data: groupIds.map((groupId) => ({
            type: "groups",
            id: String(groupId),
          })),
          links: groupsLinks,
        },
      },
    })),
    // Only what the page links to, as the server sends it.
    included: INCLUDED.filter(({ type, id }) =>
      queries.some((query) =>
        type === "users"
          ? String(query.userId) === id
          : query.groupIds.map(String).includes(id)
      )
    ),
    links: { next },
  };
}

acceptance("List Queries", function (needs) {
  needs.user();
  needs.settings({ data_explorer_enabled: true });

  let lastQueryParams;
  let lastRequestHeaders;
  let handleQueries;

  needs.hooks.beforeEach(() => {
    lastQueryParams = null;
    lastRequestHeaders = null;
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

    handleQueries = (request, next) => {
      lastQueryParams = request.queryParams;
      lastRequestHeaders = request.requestHeaders;
      const queries = [
        {
          id: -6,
          name: "Top 100 Likers",
          description:
            "returns the top 100 likers for a given monthly period ordered by like_count. It accepts a ‘months_ago’ parameter, defaults to 1 to give results for the last calendar month.",
          lastRunAt: "2021-02-11T08:29:59.337Z",
          isDefault: true,
          tags: ["default", "staff"],
          userId: -1,
          groupIds: [],
        },
        {
          id: -5,
          name: "Top 100 Active Topics",
          description:
            "based on the number of replies, it accepts a ‘months_ago’ parameter, defaults to 1 to give results for the last calendar month.",
          lastRunAt: "2021-02-08T15:37:49.188Z",
          isDefault: true,
          tags: ["default"],
          userId: -1,
          groupIds: [],
        },
        {
          id: 1,
          name: "Staff activity",
          description: "Shows staff activity.",
          lastRunAt: "2021-02-07T15:37:49.188Z",
          tags: ["staff"],
          userId: 1,
          groupIds: [41],
        },
      ];
      const tags = request.queryParams["filter[tag]"] ?? [];
      const search = request.queryParams["filter[search]"]?.toLowerCase();
      const filteredQueries = queries.filter((query) => {
        return (
          tags.every((tag) => query.tags.includes(tag)) &&
          (!search || query.name.toLowerCase().includes(search))
        );
      });

      return helper.response(toDocument(filteredQueries, next));
    };

    server.get("/api/data-explorer/queries", handleQueries);
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
      .dom(".query-row:nth-child(1) .d-table__cell-actions a")
      .hasText(i18n("explorer.view_query"), "default queries are view-only");
    assert
      .dom(".query-row:nth-child(3) .d-table__cell-actions a")
      .hasText(i18n("edit"), "custom queries are editable");

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
    assert.deepEqual(lastQueryParams["filter[tag]"], ["default", "staff"]);
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

    assert.deepEqual(lastQueryParams["filter[tag]"], ["default", "staff"]);
    assert
      .dom(".query-tag-filter .d-multi-select-trigger__selected-item")
      .exists({ count: 2 }, "both URL tags are selected");
    assert
      .dom(".recent-queries tbody tr")
      .exists({ count: 1 }, "only the query with both tags is shown");

    await fillIn(".d-filter-controls__input", "likers");
    assert.deepEqual(lastQueryParams["filter[tag]"], ["default", "staff"]);
    assert.strictEqual(lastQueryParams["filter[search]"], "likers");
  });

  test("filters by clicking a query tag", async function (assert) {
    await visit("/admin/plugins/discourse-data-explorer/queries");
    await click(".query-row:first-child .query-tags .d-table-badge:last-child");

    assert.deepEqual(lastQueryParams["filter[tag]"], ["staff"]);
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

    assert.deepEqual(
      lastQueryParams["filter[tag]"],
      ["staff"],
      "the tag is sent on return"
    );
    assert.strictEqual(
      lastQueryParams["filter[search]"],
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
      "/api/data-explorer/queries",
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

  test("requests the JSON:API endpoint with its version and sort", async function (assert) {
    await visit("/admin/plugins/discourse-data-explorer/queries");

    assert.strictEqual(lastRequestHeaders["Api-Version"], JSON_API_VERSION);
    assert.deepEqual(lastQueryParams.include, ["groups", "user"]);
    assert.strictEqual(lastQueryParams.sort, "-lastRunAt");

    await click("#table-header-toggle-username");
    assert.strictEqual(lastQueryParams.sort, "-user.username");

    await click("#table-header-toggle-username");
    assert.strictEqual(lastQueryParams.sort, "user.username");
  });

  test("renders the author and groups from included records", async function (assert) {
    await visit("/admin/plugins/discourse-data-explorer/queries");

    assert
      .dom(".query-row:nth-child(3) .query-created-by__link")
      .hasAttribute("href", "/u/admin", "links to the author");
    assert
      .dom(".query-row:nth-child(3) .query-created-by__link img.avatar")
      .exists("renders the author's avatar");
    assert
      .dom(".query-row:nth-child(3) .query-group-names")
      .includesText("analysts", "renders the group name");
  });

  test("loads the next page from the document links", async function (assert) {
    pretender.get("/api/data-explorer/queries", (request) =>
      request.queryParams["page[after]"]
        ? response(
            toDocument([
              {
                id: 2,
                name: "Older query",
                description: "",
                lastRunAt: "2021-01-01T00:00:00.000Z",
                tags: [],
                userId: 1,
                groupIds: [],
              },
            ])
          )
        : handleQueries(
            request,
            "/api/data-explorer/queries?page%5Bafter%5D=abc"
          )
    );
    await visit("/admin/plugins/discourse-data-explorer/queries");

    const controller = this.owner.lookup(
      "controller:adminPlugins.show.explorer.index"
    );
    assert.true(controller.canLoadMore, "has a next page");

    await controller.loadMore();
    await settled();

    assert
      .dom(".recent-queries tbody tr")
      .exists({ count: 4 }, "appends the next page");
    assert
      .dom(".recent-queries tbody tr:last-child td")
      .hasText(/^\s*Older query/, "renders the appended query");
    assert.false(controller.canLoadMore, "stops at the last page");
  });

  test("loads every group of a query whose groups were truncated", async function (assert) {
    pretender.get("/api/data-explorer/queries", () =>
      response(
        toDocument([
          {
            id: 7,
            name: "Widely shared",
            description: "",
            lastRunAt: "2021-01-01T00:00:00.000Z",
            tags: [],
            userId: 1,
            groupIds: [41],
            groupsLinks: {
              related: "/api/data-explorer/queries/7/groups",
              next: "/api/data-explorer/queries/7/relationships/groups?page%5Bafter%5D=abc",
            },
          },
        ])
      )
    );
    pretender.get("/api/data-explorer/queries/7/groups", () =>
      response({
        data: [
          { type: "groups", id: "41", attributes: { name: "analysts" } },
          { type: "groups", id: "42", attributes: { name: "auditors" } },
        ],
        links: { next: null },
      })
    );

    await visit("/admin/plugins/discourse-data-explorer/queries");

    assert
      .dom(".query-row .query-group-names")
      .includesText("analysts")
      .includesText("auditors", "renders the groups beyond the first page");
  });
});
