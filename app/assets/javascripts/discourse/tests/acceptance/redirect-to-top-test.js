import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { currentURL, visit } from "@ember/test-helpers";
import DiscoveryFixtures from "discourse/tests/fixtures/discovery-fixtures";
import { test } from "qunit";

acceptance("Redirect to Top", function (needs) {
  needs.pretender((server, helper) => {
    server.get("/top.json?period=weekly", () => {
      return helper.response(DiscoveryFixtures["/latest.json"]);
    });
    server.get("/top/monthly.json", () => {
      return helper.response(DiscoveryFixtures["/latest.json"]);
    });
    server.get("/top/all.json", () => {
      return helper.response(DiscoveryFixtures["/latest.json"]);
    });
  });
  needs.user();

  test("redirects categories to weekly top", async function (assert) {
    updateCurrentUser({
      should_be_redirected_to_top: true,
      redirected_to_top: {
        period: "weekly",
        reason: "Welcome back!",
      },
    });

    await visit("/categories");
    assert.equal(currentURL(), "/top?period=weekly", "it works for categories");
  });

  test("redirects latest to monthly top", async function (assert) {
    updateCurrentUser({
      should_be_redirected_to_top: true,
      redirected_to_top: {
        period: "monthly",
        reason: "Welcome back!",
      },
    });

    await visit("/latest");
    assert.equal(currentURL(), "/top?period=monthly", "it works for latest");
  });

  test("redirects root to All top", async function (assert) {
    updateCurrentUser({
      should_be_redirected_to_top: true,
      redirected_to_top: {
        period: null,
        reason: "Welcome back!",
      },
    });

    await visit("/");
    assert.equal(currentURL(), "/top?period=all", "it works for root");
  });
});
