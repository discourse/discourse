import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Topic from "discourse/models/topic";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import TopicActivityColumn from "../../discourse/components/card/topic-activity-column";

module(
  "Horizon | Integration | Component | Card | TopicActivityColumn",
  function (hooks) {
    setupRenderingTest(hooks);

    test("formats the bumpedAt date", async function (assert) {
      const topic = Topic.create({
        id: 1,
        bumped_at: "2024-06-01T12:00:00Z",
      });
      await render(
        <template><TopicActivityColumn @topic={{topic}} /></template>
      );
      assert.dom(".topic-activity__time").hasText("Jun 2024");
    });

    test("has the correct user details and class when there is only one post", async function (assert) {
      const topic = Topic.create({
        id: 1,
        bumped_at: "2024-06-01T12:00:00Z",
        posts_count: 1,
        last_poster_username: "bob",
      });
      await render(
        <template><TopicActivityColumn @topic={{topic}} /></template>
      );
      assert.dom(".topic-activity.--created").exists();
      assert.dom(".topic-activity__username").hasText("bob");
    });

    test("has the correct user details and class when there are multiple posts", async function (assert) {
      const topic = Topic.create({
        id: 1,
        bumped_at: "2024-06-01T12:00:00Z",
        posts_count: 3,
        last_poster_username: "alice",
      });
      await render(
        <template><TopicActivityColumn @topic={{topic}} /></template>
      );
      assert.dom(".topic-activity.--replied").exists();
      assert.dom(".topic-activity__username").hasText("alice");
    });

    test("shows no user and the updated class when the topic was bumped long after the last post", async function (assert) {
      const topic = Topic.create({
        id: 1,
        bumped_at: "2024-06-10T12:00:00Z",
        last_posted_at: "2024-06-01T12:00:00Z",
        posts_count: 3,
        last_poster_username: "alice",
      });
      await render(
        <template><TopicActivityColumn @topic={{topic}} /></template>
      );
      assert.dom(".topic-activity.--updated").exists();
      assert.dom(".topic-activity__username").doesNotExist();
    });
  }
);
