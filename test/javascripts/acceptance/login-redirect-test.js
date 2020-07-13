import { acceptance } from "helpers/qunit-helpers";

acceptance("Login redirect", {});

QUnit.test("redirects login to default homepage", async function(assert) {
  await visit("/login");
  assert.equal(
    currentPath(),
    "discovery.latest",
    "it works when latest is the homepage"
  );
  this.siteSettings.top_menu = "categories|latest|top|hot";

  await visit("/login");
  assert.equal(
    currentPath(),
    "discovery.categories",
    "it works when categories is the homepage"
  );
});
