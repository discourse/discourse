import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Topic from "discourse/models/topic";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import TopicActivityColumn from "../../discourse/components/card/topic-activity-column";

module(
  "Horizon | Integration | Component | Card | TopicActivityColumn",
  function (hooks) {
    setupRenderingTest(hooks);

    test("shows the topic activity month and year", async function (assert) {
      const topic = Topic.create({
        id: 1,
        bumped_at: "2024-06-01T12:00:00Z",
      });
      await render(
        <template><TopicActivityColumn @topic={{topic}} /></template>
      );
      assert.dom(".topic-activity__time").hasText("Jun 2024");
    });

    test("shows the topic creator for a topic with one post", async function (assert) {
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

    test("shows the latest replier for a topic with multiple posts", async function (assert) {
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

    test("omits the user when topic activity is not tied to a post", async function (assert) {
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
