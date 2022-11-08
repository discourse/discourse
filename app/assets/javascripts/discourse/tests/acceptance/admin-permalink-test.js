import {
  acceptance,
  exists,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("Admin - Permalinks", function (needs) {
  const startingData = [
    {
      id: 38,
      url: "c/feature/announcements",
      topic_id: null,
      topic_title: null,
      topic_url: null,
      post_id: null,
      post_url: null,
      post_number: null,
      post_topic_title: null,
      category_id: 67,
      category_name: "announcements",
      category_url: "/c/announcements/67",
      external_url: null,
      tag_id: null,
      tag_name: null,
      tag_url: null,
    },
  ];

  needs.user();
  needs.pretender((server, helper) => {
    server.get("/admin/permalinks.json", (response) => {
      response = startingData;
      return helper.response(200, response);
    });

    server.post("/admin/permalinks.json", (request) => {
      const data = helper.parsePostData(request.requestBody);
      startingData.push(data);
      return helper.response(200, data);
    });
  });

  test("search permalinks with result", async function (assert) {
    await visit("/admin/customize/permalinks");
    await fillIn(".permalink-search input", "feature");
    assert.ok(
      exists(".permalink-results span[title='c/feature/announcements']"),
      "permalink is found after search"
    );
  });

  // eslint-disable-next-line no-unused-vars
  test("search permalinks with result", async function (assert) {
    await visit("/admin/customize/permalinks");
    await fillIn(".permalink-search input", "garboogle");
    // todo - check for no results message and ensure search bar still present.
  });

  test("add permalinks", async function (assert) {
    await visit("/admin/customize/permalinks");
    await fillIn(".permalink-url", "settings");
    await click(".permalink-type .select-kit-header");
    await click(".select-kit-row[data-value='external_url']");
    await fillIn(".permalink-destination", "/admin/site_settings");
    await click(".permalink-add");
    // todo fix not inserting text values
    assert.ok(
      queryAll(".admin-logs-table.permalinks tbody tr").length === 2,
      "a new permalink is successfully added"
    );
    await this.pauseTest();
  });

  // eslint-disable-next-line no-unused-vars
  test("remove permalink", async function (assert) {
    // todo
  });
});
