import { click, currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

function topicAttrs(id, slug, title) {
  return {
    id,
    slug,
    title,
    fancy_title: title,
    posts_count: 4,
    reply_count: 3,
    highest_post_number: 4,
    last_read_post_number: 4,
    last_poster_username: "alice",
    bumped_at: "2024-06-01T12:00:00.000Z",
    last_posted_at: "2024-06-01T12:00:00.000Z",
    created_at: "2024-06-01T10:00:00.000Z",
    category_id: 1,
    visible: true,
    closed: false,
    archived: false,
    pinned: false,
    pinned_globally: false,
    deleted_at: null,
    archetype: "regular",
    details: { can_create_post: true, notification_level: 1 },
    is_nested_view: true,
  };
}

function postAttrs(topic, postNumber, id, cooked, replyToPostNumber = null) {
  return {
    id,
    topic_id: topic.id,
    topic_slug: topic.slug,
    post_number: postNumber,
    reply_to_post_number: replyToPostNumber,
    username: "alice",
    name: "Alice",
    avatar_template: "/letter_avatar_proxy/v4/letter/a/{size}.png",
    cooked: `<p>${cooked}</p>`,
    created_at: "2024-06-01T10:00:00.000Z",
    updated_at: "2024-06-01T10:00:00.000Z",
    post_type: 1,
    can_edit: true,
    can_delete: false,
    actions_summary: [],
    reply_count: 0,
    reads: 1,
    read: true,
    yours: false,
  };
}

function nestedResponse({ id, slug, title, marker, suggestedTopic }) {
  const topic = topicAttrs(id, slug, title);
  const opPost = postAttrs(topic, 1, id * 10 + 1, `${marker} op`);
  const firstReply = postAttrs(
    topic,
    2,
    id * 10 + 2,
    `${marker} first branch`,
    1
  );
  const childOne = postAttrs(topic, 3, id * 10 + 3, `${marker} child one`, 2);
  const childTwo = postAttrs(topic, 4, id * 10 + 4, `${marker} child two`, 2);

  return {
    topic,
    op_post: opPost,
    roots: [
      {
        ...firstReply,
        reply_count: 2,
        direct_reply_count: 2,
        total_descendant_count: 2,
        children: [childOne, childTwo],
      },
    ],
    page: 0,
    has_more_roots: false,
    sort: "old",
    pinned_post_ids: [],
    message_bus_last_id: id,
    suggested_topics: suggestedTopic ? [suggestedTopic] : [],
  };
}

function topicViewResponse(id, slug, title) {
  const topic = topicAttrs(id, slug, title);
  const opPost = postAttrs(topic, 1, id * 10 + 1, `${title} op`);

  return {
    ...topic,
    post_stream: {
      posts: [opPost],
      stream: [opPost.id],
    },
    timeline_lookup: [[1, 0]],
  };
}

acceptance("Horizon | Nested suggested topic navigation", function (needs) {
  needs.user();
  needs.settings({
    nested_replies_enabled: true,
    nested_replies_default_sort: "old",
  });

  needs.pretender((server, helper) => {
    const firstTopicSuggestion = topicAttrs(
      102,
      "second-nested-topic",
      "Second nested topic"
    );
    const secondTopicSuggestion = topicAttrs(
      101,
      "first-nested-topic",
      "First nested topic"
    );

    server.get("/t/101.json", () =>
      helper.response(
        topicViewResponse(101, "first-nested-topic", "First nested topic")
      )
    );

    server.get("/t/102.json", () =>
      helper.response(
        topicViewResponse(102, "second-nested-topic", "Second nested topic")
      )
    );

    server.get("/n/first-nested-topic/101.json", () =>
      helper.response(
        nestedResponse({
          id: 101,
          slug: "first-nested-topic",
          title: "First nested topic",
          marker: "FIRST_TOPIC_UNIQUE",
          suggestedTopic: firstTopicSuggestion,
        })
      )
    );

    server.get("/n/second-nested-topic/102.json", () =>
      helper.response(
        nestedResponse({
          id: 102,
          slug: "second-nested-topic",
          title: "Second nested topic",
          marker: "SECOND_TOPIC_UNIQUE",
          suggestedTopic: secondTopicSuggestion,
        })
      )
    );
  });

  test("row-clicking a suggested nested topic replaces the old root branch", async function (assert) {
    await visit("/t/first-nested-topic/101");

    assert
      .dom(".nested-view__roots")
      .includesText("FIRST_TOPIC_UNIQUE first branch");
    assert
      .dom(".nested-view__roots")
      .includesText("FIRST_TOPIC_UNIQUE child one");
    assert
      .dom("#suggested-topics .topic-list-item")
      .exists("renders suggested topics with Horizon's card row behavior");

    await click("#suggested-topics .topic-list-item");

    assert.strictEqual(currentURL(), "/t/second-nested-topic/102?sort=old");
    assert
      .dom(".nested-view__roots")
      .includesText("SECOND_TOPIC_UNIQUE first branch");
    assert
      .dom(".nested-view__roots")
      .includesText("SECOND_TOPIC_UNIQUE child one");
    assert
      .dom(".nested-view__roots")
      .doesNotIncludeText("FIRST_TOPIC_UNIQUE first branch");
    assert
      .dom(".nested-view__roots")
      .doesNotIncludeText("FIRST_TOPIC_UNIQUE child one");
  });
});
