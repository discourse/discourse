import { triggerEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import {
  acceptance,
  publishToMessageBus,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { cloneJSON } from "discourse-common/lib/object";
import topicFixtures from "../fixtures/topic";

function topicWithoutUserStatus(topicId, mentionedUserId) {
  const topic = cloneJSON(topicFixtures[`/t/${topicId}.json`]);
  topic.archetype = "regular";
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

function topicWithUserStatus(topicId, mentionedUserId, status) {
  const topic = topicWithoutUserStatus(topicId, mentionedUserId);
  topic.post_stream.posts[0].mentioned_users[0].status = status;
  return topic;
}

acceptance("Post inline mentions", function (needs) {
  needs.user();

  const topicId = 130;
  const mentionedUserId = 1;
  const status = {
    description: "Surfing",
    emoji: "surfing_man",
    ends_at: null,
  };

  test("shows user status on inline mentions", async function (assert) {
    pretender.get(`/t/${topicId}.json`, () => {
      return response(topicWithUserStatus(topicId, mentionedUserId, status));
    });

    await visit(`/t/lorem-ipsum-dolor-sit-amet/${topicId}`);

    assert
      .dom(".topic-post .cooked .mention .user-status-message")
      .exists("user status is shown");
    const statusElement = query(
      ".topic-post .cooked .mention .user-status-message img"
    );
    assert.ok(
      statusElement.src.includes(status.emoji),
      "status emoji is correct"
    );
  });

  test("inserts user status on message bus message", async function (assert) {
    pretender.get(`/t/${topicId}.json`, () => {
      return response(topicWithoutUserStatus(topicId, mentionedUserId));
    });
    await visit(`/t/lorem-ipsum-dolor-sit-amet/${topicId}`);

    assert
      .dom(".topic-post .cooked .mention .user-status-message")
      .doesNotExist("user status isn't shown");

    await publishToMessageBus("/user-status", {
      [mentionedUserId]: {
        description: status.description,
        emoji: status.emoji,
      },
    });

    assert
      .dom(".topic-post .cooked .mention .user-status-message")
      .exists("user status is shown");
    const statusElement = query(
      ".topic-post .cooked .mention .user-status-message img"
    );
    assert.ok(
      statusElement.src.includes(status.emoji),
      "status emoji is correct"
    );
  });

  test("updates user status on message bus message", async function (assert) {
    pretender.get(`/t/${topicId}.json`, () => {
      return response(topicWithUserStatus(topicId, mentionedUserId, status));
    });
    await visit(`/t/lorem-ipsum-dolor-sit-amet/${topicId}`);

    assert
      .dom(".topic-post .cooked .mention .user-status-message")
      .exists("initial user status is shown");

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

    assert
      .dom(".topic-post .cooked .mention .user-status-message")
      .exists("updated user status is shown");
    const statusElement = query(
      ".topic-post .cooked .mention .user-status-message img"
    );
    assert.ok(
      statusElement.src.includes(newStatus.emoji),
      "updated status emoji is correct"
    );
  });

  test("removes user status on message bus message", async function (assert) {
    pretender.get(`/t/${topicId}.json`, () => {
      return response(topicWithUserStatus(topicId, mentionedUserId, status));
    });
    await visit(`/t/lorem-ipsum-dolor-sit-amet/${topicId}`);

    assert
      .dom(".topic-post .cooked .mention .user-status-message")
      .exists("initial user status is shown");

    await publishToMessageBus("/user-status", {
      [mentionedUserId]: null,
    });

    assert
      .dom(".topic-post .cooked .mention .user-status-message")
      .doesNotExist("updated user has disappeared");
  });
});

acceptance("Post inline mentions – user status tooltip", function (needs) {
  needs.user();

  const topicId = 130;
  const mentionedUserId = 1;
  const status = {
    description: "Surfing",
    emoji: "surfing_man",
    ends_at: null,
  };

  async function mouseMove(selector) {
    await triggerEvent(selector, "mousemove");
  }

  test("shows user status tooltip", async function (assert) {
    pretender.get(`/t/${topicId}.json`, () => {
      return response(topicWithUserStatus(topicId, mentionedUserId, status));
    });

    await visit(`/t/lorem-ipsum-dolor-sit-amet/${topicId}`);
    assert
      .dom(".topic-post .cooked .mention .user-status-message")
      .exists("user status is shown");

    await mouseMove(".user-status-message");
    const statusTooltip = document.querySelector(
      ".user-status-message-tooltip"
    );
    assert.ok(statusTooltip, "status tooltip is shown");
    assert.ok(
      statusTooltip.querySelector("img").src.includes(status.emoji),
      "emoji is correct"
    );
    assert
      .dom(".user-status-tooltip-description", statusTooltip)
      .hasText(status.description, "status description is correct");
  });
});

acceptance("Post inline mentions as an anonymous user", function () {
  const topicId = 130;
  const mentionedUserId = 1;
  const status = {
    description: "Surfing",
    emoji: "surfing_man",
    ends_at: null,
  };

  test("an anonymous user can see user status on mentions", async function (assert) {
    pretender.get(`/t/${topicId}.json`, () => {
      const topic = topicWithUserStatus(topicId, mentionedUserId, status);
      return response(topic);
    });
    await visit(`/t/lorem-ipsum-dolor-sit-amet/${topicId}`);

    assert
      .dom(".topic-post .cooked .mention .user-status-message")
      .exists("user status is shown");
  });

  test("an anonymous user can see user status with an end date on mentions", async function (assert) {
    pretender.get(`/t/${topicId}.json`, () => {
      const statusWithEndDate = Object.assign(status, {
        ends_at: "2100-02-01T09:00:00.000Z",
      });
      const topic = topicWithUserStatus(
        topicId,
        mentionedUserId,
        statusWithEndDate
      );
      return response(topic);
    });
    await visit(`/t/lorem-ipsum-dolor-sit-amet/${topicId}`);

    assert
      .dom(".topic-post .cooked .mention .user-status-message")
      .exists("user status is shown");
  });
});
