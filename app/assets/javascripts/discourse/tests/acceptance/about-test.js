import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";

acceptance("About", function () {
  test("viewing", async function (assert) {
    await visit("/about");

    assert.ok(document.body.classList.contains("about-page"), "has body class");
    assert.ok(exists(".about.admins .user-info"), "has admins");
    assert.ok(exists(".about.moderators .user-info"), "has moderators");
    assert.ok(
      exists(".about.stats tr.about-topic-count td"),
      "has topic stats"
    );
    assert.ok(exists(".about.stats tr.about-post-count td"), "has post stats");
    assert.ok(exists(".about.stats tr.about-user-count td"), "has user stats");
    assert.ok(
      exists(".about.stats tr.about-active-user-count td"),
      "has active user stats"
    );
    assert.ok(exists(".about.stats tr.about-like-count td"), "has like stats");
    assert.ok(
      exists(".about.stats tr.about-chat_messages-count td"),
      "has plugin stats"
    );
    assert.notOk(
      exists(".about.stats tr.about-chat_users-count td"),
      "does not show hidden plugin stats"
    );
  });
});
