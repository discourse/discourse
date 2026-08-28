import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import discoveryFixtures from "discourse/tests/fixtures/discovery-fixtures";
import pretender from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const CATEGORY = {
  id: 1,
  name: "bug",
  slug: "bug",
  permission: 1,
  default_view: "unread",
};

function requestedFilters() {
  return pretender.handledRequests
    .filter((request) => request.url.includes("/c/bug/1/l/"))
    .map((request) => request.url.split("/l/")[1].split(".json")[0]);
}

// `latest` is stubbed by default, `unread` is not.
function stubUnreadList(server, helper) {
  server.get("/c/bug/1/l/unread.json", () =>
    helper.response(discoveryFixtures["/c/bug/1/l/latest.json"])
  );
}

acceptance("Category default view - anonymous", function (needs) {
  needs.site({ categories: [CATEGORY] });
  needs.pretender(stubUnreadList);

  test("falls back to latest for a view it could not request", async function (assert) {
    await visit("/c/bug/1");

    assert.deepEqual(
      requestedFilters(),
      ["latest"],
      "clamps a default view an anonymous visitor cannot reach"
    );
  });
});

acceptance("Category default view - logged in", function (needs) {
  needs.user();
  needs.site({ categories: [CATEGORY] });
  needs.pretender(stubUnreadList);

  test("honours a view it can request", async function (assert) {
    await visit("/c/bug/1");

    assert.deepEqual(
      requestedFilters(),
      ["unread"],
      "keeps a default view this visitor can reach"
    );
  });
});
