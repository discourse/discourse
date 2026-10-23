import {
  click,
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

function listDocument(id, name) {
  return {
    data: [
      {
        type: "queries",
        id,
        attributes: { name, description: "", tags: [] },
        relationships: { user: { data: null }, groups: { data: [] } },
      },
    ],
  };
}

acceptance("List Queries", function (needs) {
  needs.user();
  needs.settings({ data_explorer_enabled: true });

  let lastRequest;

  needs.hooks.beforeEach(() => {
    lastRequest = null;
  });

  needs.pretender((server, helper) => {
    server.get("/admin/plugins/discourse-data-explorer.json", () =>
      helper.response({
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
      })
    );
    server.get("/admin/plugins/discourse-data-explorer/queries/tags.json", () =>
      helper.response(["default", "staff"])
    );
    server.get("/api/data-explorer/queries", (request) => {
      lastRequest = request;
      return helper.response(listDocument("1", "Initial query"));
    });
  });

  test("requests the JSON:API endpoint with its version and sort", async function (assert) {
    await visit("/admin/plugins/discourse-data-explorer/queries");

    assert.strictEqual(
      lastRequest.requestHeaders["Api-Version"],
      JSON_API_VERSION
    );
    assert.deepEqual(lastRequest.queryParams.include, ["groups", "user"]);
    assert.strictEqual(lastRequest.queryParams.sort, "-lastRunAt");

    await click("#table-header-toggle-username");
    assert.strictEqual(lastRequest.queryParams.sort, "-user.username");

    await click("#table-header-toggle-username");
    assert.strictEqual(lastRequest.queryParams.sort, "user.username");
  });

  test("sends the tag filter and search as JSON:API filters", async function (assert) {
    await visit(
      "/admin/plugins/discourse-data-explorer/queries?tags=default,staff"
    );

    assert.deepEqual(lastRequest.queryParams["filter[tag]"], [
      "default",
      "staff",
    ]);

    await fillIn(".d-filter-controls__input", "likers");

    assert.deepEqual(lastRequest.queryParams["filter[tag]"], [
      "default",
      "staff",
    ]);
    assert.strictEqual(lastRequest.queryParams["filter[search]"], "likers");
  });

  test("ignores an older tag-filter response that finishes last", async function (assert) {
    await visit("/admin/plugins/discourse-data-explorer/queries");

    const requests = [];
    pretender.get(
      "/api/data-explorer/queries",
      (request) => {
        requests.push(request);
        if (request.queryParams["filter[tag]"]?.includes("default")) {
          return response(listDocument("2", "Top 100 Likers"));
        }
        return response(listDocument("3", "Staff activity"));
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
      find(".recent-queries tbody tr td")?.textContent.includes(
        "Staff activity"
      )
    );
    pretender.resolve(requests[0]);
    await settled();

    assert
      .dom(".recent-queries tbody tr td")
      .hasText(
        /^\s*Staff activity/,
        "the latest filter results remain visible"
      );
  });
});
