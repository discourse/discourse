import { acceptance } from "helpers/qunit-helpers";

acceptance("Login redirect", {});

QUnit.test("redirects categories to top", async assert => {
  await visit("/login");
  assert.equal(
    currentPath(),
    "discovery.latest",
    "it works when latest is the homepage"
  );
  Discourse.SiteSettings.top_menu = "categories|latest|top|hot";

  await visit("/login");
  assert.equal(
    currentPath(),
    "discovery.categories",
    "it works when categories is the homepage"
  );
});
