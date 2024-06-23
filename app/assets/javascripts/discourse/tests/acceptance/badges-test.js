import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("Badges", function (needs) {
  needs.user();

  test("Visit Badge Pages", async function (assert) {
    await visit("/badges");

    assert.dom(document.body).hasClass("badges-page", "has body class");
    assert.dom(".badge-groups .badge-card").exists("has a list of badges");

    await visit("/badges/9/autobiographer");

    assert.dom(".badge-card").exists("has the badge in the listing");
    assert.dom(".user-info").exists("has the list of users with that badge");
    assert.dom(".badge-card:nth-of-type(1) script").doesNotExist();
  });

  test("shows correct badge titles to choose from", async function (assert) {
    const availableBadgeTitles = selectKit(".select-kit");
    await visit("/badges/50/custombadge");
    await availableBadgeTitles.expand();

    assert.strictEqual(
      availableBadgeTitles.rowByIndex(1).name(),
      "CustomBadge"
    );
  });
});
