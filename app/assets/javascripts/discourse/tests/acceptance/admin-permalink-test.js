import { fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

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
      const result =
        response.queryParams.filter !== "feature" ? [] : startingData;
      return helper.response(200, result);
    });
  });

  test("search permalinks with result", async function (assert) {
    await visit("/admin/customize/permalinks");
    await fillIn(".permalink-search input", "feature");
    assert
      .dom(".permalink-results span[title='c/feature/announcements']")
      .exists("permalink is found after search");
  });

  test("search permalinks without results", async function (assert) {
    await visit("/admin/customize/permalinks");
    await fillIn(".permalink-search input", "garboogle");

    assert
      .dom(".permalink-results__no-result")
      .exists("no results message shown");

    assert.dom(".permalink-search").exists("search input still visible");
  });
});
