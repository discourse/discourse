import { acceptance, logIn, replaceCurrentUser } from "helpers/qunit-helpers";
import DiscoveryFixtures from "fixtures/discovery_fixtures";

acceptance("Redirect to Top", {
  pretend(server, helper) {
    server.get("/top/all.json", () => {
      return helper.response(DiscoveryFixtures["/latest.json"]);
    });
  }
});

function setupUser() {
  logIn();
  replaceCurrentUser({
    should_be_redirected_to_top: true,
    redirected_to_top: {
      period: null,
      reason: "Welcome back!"
    }
  });
}

QUnit.test("redirects categories to top", async assert => {
  setupUser();
  await visit("/categories");
  assert.equal(currentPath(), "discovery.topAll", "it works for categories");
});

QUnit.test("redirects latest to top", async assert => {
  setupUser();
  await visit("/latest");
  assert.equal(currentPath(), "discovery.topAll", "it works for latest");
});

QUnit.test("redirects root to top", async assert => {
  setupUser();
  await visit("/");
  assert.equal(currentPath(), "discovery.topAll", "it works for root");
});
