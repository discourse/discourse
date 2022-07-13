import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";

acceptance("About", function () {
  test("viewing", async function (assert) {
    await visit("/about");

    assert.ok(document.body.classList.contains("about-page"), "has body class");
    assert.ok(exists(".about.admins .user-info"), "has admins");
    assert.ok(exists(".about.moderators .user-info"), "has moderators");
    assert.ok(exists(".about.stats tr td"), "has stats");
  });
});
