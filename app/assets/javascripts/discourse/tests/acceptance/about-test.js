import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("About", function () {
  test("viewing", async function (assert) {
    await visit("/about");

    assert.dom(document.body).hasClass("about-page", "has body class");
    assert.dom(".about.admins .user-info").exists("has admins");
    assert.dom(".about.moderators .user-info").exists("has moderators");
    assert
      .dom(".about.stats tr.about-topic-count td")
      .exists("has topic stats");
    assert.dom(".about.stats tr.about-post-count td").exists("has post stats");
    assert.dom(".about.stats tr.about-user-count td").exists("has user stats");
    assert
      .dom(".about.stats tr.about-active-user-count td")
      .exists("has active user stats");
    assert.dom(".about.stats tr.about-like-count td").exists("has like stats");
    assert
      .dom(".about.stats tr.about-chat_messages-count td")
      .exists("has plugin stats");
    assert
      .dom(".about.stats tr.about-chat_users-count td")
      .doesNotExist("does not show hidden plugin stats");
  });
});
