import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Topic from "discourse/models/topic";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import HighContextTopicCard from "../../discourse/components/card/high-context-topic-card";

module(
  "Horizon | Integration | Component | Card | HighContextTopicCard",
  function (hooks) {
    setupRenderingTest(hooks);

    test("shows the last reply line with the actual reply time when a reply is recent", async function (assert) {
      const topic = Topic.create({
        id: 1,
        bumped_at: "2024-06-01T12:00:00Z",
        last_posted_at: "2024-06-01T12:00:00Z",
        last_poster_username: "alice",
        posts_count: 3,
        reply_count: 2,
      });
      await render(
        <template><HighContextTopicCard @topic={{topic}} /></template>
      );
      assert.dom(".hc-topic-card__last-reply").exists();
      assert.dom(".hc-topic-card__last-reply-name").hasText("alice");
    });

    test("hides the last reply line when the topic was bumped more than a day after the last post", async function (assert) {
      // This case represents an OP edit (or wiki conversion) bumping the
      // topic well after the last actual reply. The card used to show
      // "{last_poster} replied {bumped_at}" which read as "replied just
      // now" when the real reply was days earlier.
      const topic = Topic.create({
        id: 1,
        bumped_at: "2024-06-10T12:00:00Z",
        last_posted_at: "2024-06-01T12:00:00Z",
        last_poster_username: "alice",
        posts_count: 3,
        reply_count: 2,
      });
      await render(
        <template><HighContextTopicCard @topic={{topic}} /></template>
      );
      assert.dom(".hc-topic-card__last-reply").doesNotExist();
    });
  }
);
