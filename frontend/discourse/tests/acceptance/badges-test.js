import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import badgesFixtures from "discourse/tests/fixtures/badges-fixture";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("Badges", function (needs) {
  needs.user();

  test("Visit Badge Pages", async function (assert) {
    await visit("/badges");

    assert.dom(document.body).hasClass("badges-page", "has body class");
    assert.dom(".badge-groups .badge-card").exists("has a list of badges");
    assert
      .dom(".badge-grouping h2#getting-started")
      .exists("badge grouping titles have slugified ids");

    await visit("/badges/9/autobiographer");

    assert.dom(".badge-card").exists("has the badge in the listing");
    assert.dom(".user-info").exists("has the list of users with that badge");
    assert.dom(".badge-card:nth-of-type(1) script").doesNotExist();
  });

  test("shows correct badge titles to choose from", async function (assert) {
    await visit("/badges/50/custombadge");
    await click(".badge-grant-info .btn-default");

    const availableBadgeTitles = selectKit(".badge-set-title .select-kit");
    await availableBadgeTitles.expand();

    assert.strictEqual(
      availableBadgeTitles.rowByIndex(1).name(),
      "CustomBadge"
    );
  });
});

acceptance("Badges - recent grants feed", function (needs) {
  needs.user();

  let grantQueries = [];

  needs.pretender((server, helper) => {
    server.get("/user_badges.json", (request) => {
      grantQueries.push(request.queryParams);
      const payload = cloneJSON(badgesFixtures["/user_badges.json"]);
      payload.user_badge_info = {
        grant_count: null,
        username: null,
        user_badges: payload.user_badges.slice(0, 2),
      };
      return helper.response(payload);
    });
  });

  test("stops loading more grants when the page is shorter than the page size", async function (assert) {
    await visit("/badges/9/autobiographer");

    assert.strictEqual(
      grantQueries.length,
      1,
      "requests a single page of grants"
    );
    assert.strictEqual(grantQueries[0].limit, "96", "asks for a full page");

    assert
      .dom(".show-badge .loading-container .spinner")
      .doesNotExist("does not offer to load grants the viewer cannot see");
  });
});
