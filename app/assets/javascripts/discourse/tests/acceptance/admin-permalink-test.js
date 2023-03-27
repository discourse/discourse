import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import { fillIn, visit } from "@ember/test-helpers";
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
      const result =
        response.queryParams.filter !== "feature" ? [] : startingData;
      return helper.response(200, result);
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

  test("search permalinks without results", async function (assert) {
    await visit("/admin/customize/permalinks");
    await fillIn(".permalink-search input", "garboogle");

    assert.ok(
      exists(".permalink-results__no-result"),
      "no results message shown"
    );

    assert.ok(exists(".permalink-search"), "search input still visible");
  });
});
