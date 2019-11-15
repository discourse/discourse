import { acceptance, updateCurrentUser } from "helpers/qunit-helpers";
import DiscoveryFixtures from "fixtures/discovery_fixtures";

acceptance("Redirect to Top", {
  pretend(server, helper) {
    server.get("/top/weekly.json", () => {
      return helper.response(DiscoveryFixtures["/latest.json"]);
    });
    server.get("/top/monthly.json", () => {
      return helper.response(DiscoveryFixtures["/latest.json"]);
    });
    server.get("/top/all.json", () => {
      return helper.response(DiscoveryFixtures["/latest.json"]);
    });
  },
  loggedIn: true
});

QUnit.test("redirects categories to weekly top", async assert => {
  updateCurrentUser({
    should_be_redirected_to_top: true,
    redirected_to_top: {
      period: "weekly",
      reason: "Welcome back!"
    }
  });

  await visit("/categories");
  assert.equal(currentPath(), "discovery.topWeekly", "it works for categories");
});

QUnit.test("redirects latest to monthly top", async assert => {
  updateCurrentUser({
    should_be_redirected_to_top: true,
    redirected_to_top: {
      period: "monthly",
      reason: "Welcome back!"
    }
  });

  await visit("/latest");
  assert.equal(currentPath(), "discovery.topMonthly", "it works for latest");
});

QUnit.test("redirects root to All top", async assert => {
  updateCurrentUser({
    should_be_redirected_to_top: true,
    redirected_to_top: {
      period: null,
      reason: "Welcome back!"
    }
  });

  await visit("/");
  assert.equal(currentPath(), "discovery.topAll", "it works for root");
});
