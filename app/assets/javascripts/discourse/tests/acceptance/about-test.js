import { exists } from "discourse/tests/helpers/qunit-helpers";
import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("About", function () {
  test("viewing", async (assert) => {
    await visit("/about");

    assert.ok($("body.about-page").length, "has body class");
    assert.ok(exists(".about.admins .user-info"), "has admins");
    assert.ok(exists(".about.moderators .user-info"), "has moderators");
    assert.ok(exists(".about.stats tr td"), "has stats");
  });
});
