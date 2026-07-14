import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { ComposerActionItemBuilder } from "discourse/lib/composer/action-items";
import {
  CREATE_SHARED_DRAFT,
  CREATE_TOPIC,
  PRIVATE_MESSAGE,
  REPLY,
} from "discourse/models/composer";
import { logIn } from "discourse/tests/helpers/qunit-helpers";

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

module("Unit | Lib | composer action items", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    logIn(this.owner);
    this.composerActionState = this.owner.lookup(
      "service:composer-action-state"
    );
    this.composerActionState.clear();
    this.owner.lookup("service:site").set("shared_drafts_category_id", null);
  });

  function build(testContext, context = {}) {
    const {
      action = REPLY,
      topic: topicArg = topic(),
      post: postArg = null,
      replyOptions = {},
      composerModel = {},
      snapshots = {},
    } = context;

    if (snapshots.topic || snapshots.post) {
      testContext.composerActionState.remember({
        topic: snapshots.topic,
        post: snapshots.post,
      });
    }

    if (context.site) {
      testContext.owner.lookup("service:site").setProperties(context.site);
    }

    return new ComposerActionItemBuilder(
      testContext,
      action,
      topicArg,
      postArg,
      replyOptions,
      composerModel
    ).build();
  }

  function ids(testContext, context) {
    return build(testContext, context).map((item) => item.id);
  }

  test("reply to post", function (assert) {
    assert.deepEqual(
      ids(this, {
        post: post(),
        replyOptions: {
          userAvatar: true,
          userLink: true,
          topicLink: true,
        },
      }),
      ["reply_to_topic", "reply_as_new_topic"]
    );
  });

  test("reply to topic", function (assert) {
    assert.deepEqual(
      ids(this, {
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
      ids(this, {
        topic: topic({ isPrivateMessage: false }),
      }).includes("reply_as_new_topic")
    );
  });

  test("reply as new group message", function (assert) {
    assert.deepEqual(
      ids(this, {
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
      ids(this, {
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
      ids(this, {
        action: CREATE_TOPIC,
        topic: null,
        snapshots: {},
      }),
      ["create_private_message"]
    );

    assert.deepEqual(
      ids(this, {
        action: PRIVATE_MESSAGE,
        topic: null,
        snapshots: {},
      }),
      ["create_topic"]
    );
  });

  test("shared draft and PM/create topic switching options", function (assert) {
    assert.deepEqual(
      ids(this, {
        action: CREATE_TOPIC,
        topic: null,
        site: { shared_drafts_category_id: 24 },
      }),
      ["shared_draft", "create_private_message"]
    );

    assert.deepEqual(
      ids(this, {
        action: CREATE_SHARED_DRAFT,
        topic: null,
      }),
      ["create_topic", "create_private_message"]
    );

    assert.deepEqual(
      ids(this, {
        action: PRIVATE_MESSAGE,
        topic: null,
        snapshots: { topic: topic() },
      }),
      ["create_topic", "reply_to_topic"]
    );
  });

  test("toggle actions are included when composer allows them", function (assert) {
    const composer = this.owner.lookup("service:composer");
    sinon.stub(composer, "canToggleWhisper").value(true);
    sinon.stub(composer, "canToggleNoBump").value(true);
    sinon.stub(composer, "canUnlistTopic").value(true);

    const composerModel = {
      whisper: true,
      noBump: false,
      unlistTopic: true,
      toggleProperty() {},
    };

    const items = build(this, {
      action: REPLY,
      topic: topic(),
      composerModel,
    });

    const toggleWhisper = items.find((item) => item.id === "toggle_whisper");
    const toggleTopicBump = items.find(
      (item) => item.id === "toggle_topic_bump"
    );
    const toggleUnlisted = items.find((item) => item.id === "toggle_unlisted");

    assert.true(toggleWhisper?.isToggle, "includes whisper toggle");
    assert.true(toggleWhisper?.state, "whisper state reads from model");

    assert.true(toggleTopicBump?.isToggle, "includes no-bump toggle");
    assert.false(toggleTopicBump?.state, "no-bump state reads from model");

    assert.true(toggleUnlisted?.isToggle, "includes unlisted toggle");
    assert.true(toggleUnlisted?.state, "unlisted state reads from model");
  });

  test("toggle actions are excluded when composer disallows them", function (assert) {
    const composer = this.owner.lookup("service:composer");
    sinon.stub(composer, "canToggleWhisper").value(false);
    sinon.stub(composer, "canToggleNoBump").value(false);
    sinon.stub(composer, "canUnlistTopic").value(false);

    const actionIds = ids(this, {
      action: CREATE_TOPIC,
      topic: topic(),
      composerModel: {
        whisper: false,
        noBump: false,
        unlistTopic: false,
        toggleProperty() {},
      },
    });

    assert.false(actionIds.includes("toggle_whisper"));
    assert.false(actionIds.includes("toggle_topic_bump"));
    assert.false(actionIds.includes("toggle_unlisted"));
  });
});
