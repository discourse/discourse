import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import TopicFixtures from "discourse/tests/fixtures/topic";
import {
  acceptance,
  publishToMessageBus,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("Topic - User Status", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.get("/t/299/1.json", () => {
      const response = cloneJSON(TopicFixtures["/t/299/1.json"]);
      response.post_stream.posts.forEach((post) => {
        post.user_status = { emoji: "tooth", description: "off to dentist" };

        // we need the poster's name to be different from username
        // so when display_name_on_posts = true, both name and username will be shown:
        post.name = "Evil T";
      });

      return helper.response(200, response);
    });
  });

  test("shows user status next to avatar on posts", async function (assert) {
    this.siteSettings.enable_user_status = true;
    await visit("/t/-/299/1");

    assert
      .dom(".topic-post .user-status-message")
      .exists({ count: 3 }, "all posts has user status");
  });

  test("shows user status next to avatar on posts when displaying names on posts is enabled", async function (assert) {
    this.siteSettings.enable_user_status = true;
    this.siteSettings.display_name_on_posts = true;

    await visit("/t/-/299/1");

    assert
      .dom(".topic-post .user-status-message")
      .exists({ count: 3 }, "all posts has user status");
  });
});

acceptance("Topic - User Status - live updates", function (needs) {
  const userId = 1;

  needs.user();
  needs.pretender((server, helper) => {
    server.get("/t/299/1.json", () => {
      const response = cloneJSON(TopicFixtures["/t/299/1.json"]);
      response.post_stream.posts.forEach((post) => {
        post.user_id = userId;
        post.user_status = { emoji: "tooth", description: "off to dentist" };
      });

      return helper.response(200, response);
    });
  });

  test("updating status", async function (assert) {
    this.siteSettings.enable_user_status = true;

    await visit("/t/-/299/1");
    assert
      .dom(".topic-post .user-status-message")
      .exists({ count: 3 }, "all posts has user status");
    assert
      .dom(".topic-post .user-status-message .emoji")
      .hasAttribute("src", /tooth/, "status emoji is correct");

    const newStatus = { emoji: "surfing_man", description: "surfing" };
    await publishToMessageBus(`/user-status`, { [userId]: newStatus });

    assert
      .dom(".topic-post .user-status-message")
      .exists({ count: 3 }, "all posts has user status");
    assert
      .dom(".topic-post .user-status-message .emoji")
      .hasAttribute("src", /surfing_man/, "status emoji is correct");
  });

  test("removing status and setting again", async function (assert) {
    this.siteSettings.enable_user_status = true;

    await visit("/t/-/299/1");
    assert
      .dom(".topic-post .user-status-message")
      .exists({ count: 3 }, "all posts has user status");
    assert
      .dom(".topic-post .user-status-message .emoji")
      .hasAttribute("src", /tooth/, "status emoji is correct");

    await publishToMessageBus(`/user-status`, { [userId]: null });

    assert
      .dom(".topic-post .user-status-message")
      .doesNotExist("status on all posts has disappeared");

    const newStatus = { emoji: "surfing_man", description: "surfing" };
    await publishToMessageBus(`/user-status`, { [userId]: newStatus });

    assert
      .dom(".topic-post .user-status-message")
      .exists({ count: 3 }, "all posts have user status");
    assert
      .dom(".topic-post .user-status-message .emoji")
      .hasAttribute("src", /surfing_man/, "status emoji is correct");
  });
});
