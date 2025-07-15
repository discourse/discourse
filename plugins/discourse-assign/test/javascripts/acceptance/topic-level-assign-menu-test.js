import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  publishToMessageBus,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import topicWithAssignedPosts from "../fixtures/topic-with-assigned-posts";

const topic = topicWithAssignedPosts();
const post = topic.post_stream.posts[1];

acceptance("Discourse Assign | Topic level assign menu", function (needs) {
  needs.user();
  needs.settings({
    assign_enabled: true,
  });

  needs.pretender((server, helper) => {
    server.get("/t/44.json", () => helper.response(topic));
    server.put("/assign/unassign", () => {
      return helper.response({ success: true });
    });
  });

  needs.hooks.beforeEach(() => {
    updateCurrentUser({ can_assign: true });
  });

  test("Unassign button unassigns the post", async function (assert) {
    await visit("/t/assignment-topic/44");

    await click("#topic-footer-dropdown-reassign .btn");
    await click(`li[data-value='unassign-from-post-${post.id}']`);
    await publishToMessageBus("/staff/topic-assignment", {
      type: "unassigned",
      topic_id: topic.id,
      post_id: post.id,
      assigned_type: "User",
    });

    assert
      .dom("#topic-footer-dropdown-reassign-body ul[role='menu']")
      .doesNotExist("The menu is closed");
    assert
      .dom(".post-stream article#post_2 .assigned-to")
      .doesNotExist("The post is unassigned");
  });
});
