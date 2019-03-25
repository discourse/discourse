import { acceptance } from "helpers/qunit-helpers";

acceptance("Search - Mobile", { mobileView: true });

QUnit.test("search", async assert => {
  await visit("/");

  await click("#search-button");

  assert.ok(
    exists("input.full-page-search"),
    "it shows the full page search form"
  );
  assert.ok(!exists(".search-results .fps-topic"), "no results by default");

  await fillIn(".search-query", "posts");
  await click(".search-cta");

  assert.ok(find(".fps-topic").length === 1, "has one post");

  await click("#search-button");

  assert.equal(
    find("input.full-page-search").val(),
    "posts",
    "it does not reset input when hitting search icon again"
  );
});
