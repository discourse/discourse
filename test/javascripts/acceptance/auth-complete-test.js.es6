import { acceptance } from "helpers/qunit-helpers";
acceptance("Auth Complete", {
  beforeEach() {
    const node = document.createElement("meta");
    node.dataset.authenticationData = JSON.stringify({
      auth_provider: "test",
      email: "blah@example.com"
    });
    node.id = "data-authentication";
    document.querySelector("head").appendChild(node);
  },
  afterEach() {
    document
      .querySelector("head")
      .removeChild(document.getElementById("data-authentication"));
  }
});

QUnit.test("when login not required", async assert => {
  await visit("/");

  assert.equal(currentPath(), "discovery.latest", "it stays on the homepage");

  assert.ok(
    exists("#discourse-modal div.create-account"),
    "it shows the registration modal"
  );
});

QUnit.test("when login required", async assert => {
  Discourse.SiteSettings.login_required = true;
  await visit("/");

  assert.equal(currentPath(), "login", "it redirects to the login page");

  assert.ok(
    exists("#discourse-modal div.create-account"),
    "it shows the registration modal"
  );
});
