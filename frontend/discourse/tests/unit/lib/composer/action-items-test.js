import { module, test } from "qunit";
import { buildComposerActionItems } from "discourse/lib/composer/action-items";
import {
  CREATE_SHARED_DRAFT,
  CREATE_TOPIC,
  PRIVATE_MESSAGE,
  REPLY,
} from "discourse/models/composer";

function build(context = {}) {
  return buildComposerActionItems({
    action: REPLY,
    topic: topic(),
    post: null,
    replyOptions: {},
    snapshots: {},
    currentUser: {
      can_create_topic: true,
      can_send_private_messages: true,
    },
    site: {},
    composerModel: {},
    isEditing: false,
    postDisplayName: (replyPost) => replyPost?.username,
    ...context,
  });
}

function ids(context) {
  return build(context).map((item) => item.id);
}

function topic(attrs = {}) {
  return {
    id: 1,
    title: "Test topic",
    isPrivateMessage: false,
    ...attrs,
  };
}

function post(attrs = {}) {
  return {
    id: 10,
    username: "codinghorror",
    ...attrs,
  };
}

module("Unit | Lib | composer action items", function () {
  test("reply to post", function (assert) {
    assert.deepEqual(
      ids({
        post: post(),
        replyOptions: {
          userAvatar: true,
          userLink: true,
          topicLink: true,
        },
      }),
      ["reply_as_new_topic", "reply_to_topic"]
    );
  });

  test("reply to topic", function (assert) {
    assert.deepEqual(
      ids({
        post: null,
        replyOptions: {
          topicLink: true,
        },
      }),
      ["reply_as_new_topic"]
    );
  });

  test("reply as new topic", function (assert) {
    assert.true(
      ids({
        topic: topic({ isPrivateMessage: false }),
      }).includes("reply_as_new_topic")
    );
  });

  test("reply as new group message", function (assert) {
    assert.deepEqual(
      ids({
        topic: topic({
          isPrivateMessage: true,
          details: {
            allowed_users: [{ username: "one" }, { username: "two" }],
            allowed_groups: [],
          },
        }),
      }),
      ["reply_as_new_group_message"]
    );
  });

  test("create topic with snapshots restores reply targets", function (assert) {
    assert.deepEqual(
      ids({
        action: CREATE_TOPIC,
        topic: null,
        snapshots: {
          topic: topic(),
          post: post(),
        },
      }),
      ["reply_to_post", "reply_to_topic", "create_private_message"]
    );
  });

  test("fresh create topic/message with no snapshots does not show stale reply targets", function (assert) {
    assert.deepEqual(
      ids({
        action: CREATE_TOPIC,
        topic: null,
        snapshots: {},
      }),
      ["create_private_message"]
    );

    assert.deepEqual(
      ids({
        action: PRIVATE_MESSAGE,
        topic: null,
        snapshots: {},
      }),
      ["create_topic"]
    );
  });

  test("shared draft and PM/create-topic switching options", function (assert) {
    assert.deepEqual(
      ids({
        action: CREATE_TOPIC,
        topic: null,
        site: { shared_drafts_category_id: 24 },
      }),
      ["shared_draft", "create_private_message"]
    );

    assert.deepEqual(
      ids({
        action: CREATE_SHARED_DRAFT,
        topic: null,
      }),
      ["create_topic", "create_private_message"]
    );

    assert.deepEqual(
      ids({
        action: PRIVATE_MESSAGE,
        topic: null,
        snapshots: { topic: topic() },
      }),
      ["reply_to_topic", "create_topic"]
    );
  });
});
