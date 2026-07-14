import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Topic from "discourse/models/topic";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import HighContextTopicCard from "../../discourse/components/card/high-context-topic-card";

function topicFor(attrs = {}) {
  return Topic.create({
    id: 1,
    title: "How do cards work?",
    fancy_title: "How do cards work?",
    created_at: "2024-06-01T08:00:00Z",
    bumped_at: "2024-06-01T18:00:00Z",
    last_posted_at: "2024-06-01T12:00:00Z",
    last_poster_username: "alice",
    posts_count: 3,
    like_count: 0,
    tags: [],
    posters: [
      {
        extras: "latest single",
        user: {
          id: 1,
          username: "alice",
          name: "Alice",
          avatar_template: "/letter_avatar_proxy/v4/letter/a/{size}.png",
        },
      },
    ],
    ...attrs,
  });
}

module(
  "Horizon | Integration | Component | Card | HighContextTopicCard",
  function (hooks) {
    setupRenderingTest(hooks);

    test("shows the last reply line with the actual reply time when a reply is recent", async function (assert) {
      const lastPostedAt = "2024-06-01T12:00:00Z";
      const topic = topicFor({
        bumped_at: "2024-06-01T18:00:00Z",
        last_posted_at: lastPostedAt,
      });

      await render(
        <template>
          <HighContextTopicCard @topic={{topic}} @hideCategory={{true}} />
        </template>
      );

      assert.dom(".hc-topic-card__last-reply").exists();
      assert.dom(".hc-topic-card__last-reply-name").hasText("alice");
      assert
        .dom(".hc-topic-card__time .relative-date")
        .hasAttribute("data-time", String(new Date(lastPostedAt).getTime()));
    });

    test("hides the last reply line when the topic was bumped more than a day after the last post", async function (assert) {
      const topic = topicFor({
        bumped_at: "2024-06-10T12:00:00Z",
        last_posted_at: "2024-06-01T12:00:00Z",
      });

      await render(
        <template>
          <HighContextTopicCard @topic={{topic}} @hideCategory={{true}} />
        </template>
      );

      assert.dom(".hc-topic-card__last-reply").doesNotExist();
      assert.dom(".hc-topic-card__context").doesNotExist();
    });
  }
);
