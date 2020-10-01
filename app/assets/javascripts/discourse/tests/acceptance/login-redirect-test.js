import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Login redirect");
QUnit.test("redirects login to default homepage", async function (assert) {
  await visit("/login");
  assert.equal(
    currentPath(),
    "discovery.latest",
    "it works when latest is the homepage"
  );
});

acceptance("Login redirect - categories default", {
  settings: {
    top_menu: "categories|latest|top|hot",
  },
});

QUnit.test("when site setting is categories", async function (assert) {
  await visit("/login");
  assert.equal(
    currentPath(),
    "discovery.categories",
    "it works when categories is the homepage"
  );
});
