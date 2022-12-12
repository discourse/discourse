import {
  acceptance,
  exists,
  publishToMessageBus,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse-common/lib/object";
import topicFixtures from "../fixtures/topic";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

acceptance("Post inline mentions test", function (needs) {
  needs.user();

  const topicId = 130;
  const mentionedUserId = 1;
  const status = {
    description: "Surfing",
    emoji: "surfing_man",
    ends_at: null,
  };

  function topicWithoutUserStatus() {
    const topic = cloneJSON(topicFixtures[`/t/${topicId}.json`]);
    const firstPost = topic.post_stream.posts[0];
    firstPost.cooked =
      '<p>I am mentioning <a class="mention" href="/u/user1">@user1</a> again.</p>';
    firstPost.mentioned_users = [
      {
        id: mentionedUserId,
        username: "user1",
        avatar_template: "/letter_avatar_proxy/v4/letter/a/bbce88/{size}.png",
      },
    ];
    return topic;
  }

  function topicWithUserStatus() {
    const topic = topicWithoutUserStatus();
    topic.post_stream.posts[0].mentioned_users[0].status = status;
    return topic;
  }

  test("shows user status on inline mentions", async function (assert) {
    pretender.get(`/t/${topicId}.json`, () => {
      return response(topicWithUserStatus());
    });

    await visit(`/t/lorem-ipsum-dolor-sit-amet/${topicId}`);

    assert.ok(
      exists(".topic-post .cooked .mention .user-status"),
      "user status is shown"
    );
    const statusElement = query(".topic-post .cooked .mention .user-status");
    assert.equal(
      statusElement.title,
      status.description,
      "status description is correct"
    );
    assert.ok(
      statusElement.src.includes(status.emoji),
      "status emoji is correct"
    );
  });

  test("inserts user status on message bus message", async function (assert) {
    pretender.get(`/t/${topicId}.json`, () => {
      return response(topicWithoutUserStatus());
    });
    await visit(`/t/lorem-ipsum-dolor-sit-amet/${topicId}`);

    assert.notOk(
      exists(".topic-post .cooked .mention .user-status"),
      "user status isn't shown"
    );

    await publishToMessageBus("/user-status", {
      [mentionedUserId]: {
        description: status.description,
        emoji: status.emoji,
      },
    });

    assert.ok(
      exists(".topic-post .cooked .mention .user-status"),
      "user status is shown"
    );
    const statusElement = query(".topic-post .cooked .mention .user-status");
    assert.equal(
      statusElement.title,
      status.description,
      "status description is correct"
    );
    assert.ok(
      statusElement.src.includes(status.emoji),
      "status emoji is correct"
    );
  });

  test("updates user status on message bus message", async function (assert) {
    pretender.get(`/t/${topicId}.json`, () => {
      return response(topicWithUserStatus());
    });
    await visit(`/t/lorem-ipsum-dolor-sit-amet/${topicId}`);

    assert.ok(
      exists(".topic-post .cooked .mention .user-status"),
      "initial user status is shown"
    );

    const newStatus = {
      description: "off to dentist",
      emoji: "tooth",
    };
    await publishToMessageBus("/user-status", {
      [mentionedUserId]: {
        description: newStatus.description,
        emoji: newStatus.emoji,
      },
    });

    assert.ok(
      exists(".topic-post .cooked .mention .user-status"),
      "updated user status is shown"
    );
    const statusElement = query(".topic-post .cooked .mention .user-status");
    assert.equal(
      statusElement.title,
      newStatus.description,
      "updated status description is correct"
    );
    assert.ok(
      statusElement.src.includes(newStatus.emoji),
      "updated status emoji is correct"
    );
  });

  test("removes user status on message bus message", async function (assert) {
    pretender.get(`/t/${topicId}.json`, () => {
      return response(topicWithUserStatus());
    });
    await visit(`/t/lorem-ipsum-dolor-sit-amet/${topicId}`);

    assert.ok(
      exists(".topic-post .cooked .mention .user-status"),
      "initial user status is shown"
    );

    await publishToMessageBus("/user-status", {
      [mentionedUserId]: null,
    });

    assert.notOk(
      exists(".topic-post .cooked .mention .user-status"),
      "updated user has disappeared"
    );
  });
});
