import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";

acceptance("Badges", function (needs) {
  needs.user();

  test("Visit Badge Pages", async function (assert) {
    await visit("/badges");

    assert.ok(
      document.body.classList.contains("badges-page"),
      "has body class"
    );
    assert.ok(exists(".badge-groups .badge-card"), "has a list of badges");

    await visit("/badges/9/autobiographer");

    assert.ok(exists(".badge-card"), "has the badge in the listing");
    assert.ok(exists(".user-info"), "has the list of users with that badge");
    assert.ok(!exists(".badge-card:nth-of-type(1) script"));
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
