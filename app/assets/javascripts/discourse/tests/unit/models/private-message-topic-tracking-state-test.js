import { test } from "qunit";
import pretender from "discourse/tests/helpers/create-pretender";
import {
  discourseModule,
  publishToMessageBus,
} from "discourse/tests/helpers/qunit-helpers";
import MessageBus from "message-bus-client";
import PrivateMessageTopicTrackingState from "discourse/models/private-message-topic-tracking-state";
import User from "discourse/models/user";

function setupPretender() {
  pretender.get(`/u/test/private-message-topic-tracking-state`, () => {
    return [
      200,
      { "Content-Type": "application/json" },
      [
        {
          topic_id: 123,
          highest_post_number: 12,
          last_read_post_number: 12,
          notification_level: 3,
          group_ids: [],
        },
      ],
    ];
  });
}

discourseModule(
  "Unit | Model | private-message-topic-tracking-state",
  function (hooks) {
    let pmTopicTrackingState;

    hooks.beforeEach(function () {
      pmTopicTrackingState = PrivateMessageTopicTrackingState.create({
        messageBus: MessageBus,
        currentUser: User.create({ id: 77889, username: "test" }),
      });
    });

    test("modifying state calls onStateChange callbacks", function (assert) {
      let callbackCalled = false;

      pmTopicTrackingState.onStateChange("testing", () => {
        callbackCalled = true;
      });

      pmTopicTrackingState.set("isTracking", true);
      pmTopicTrackingState.removeTopics([]);

      assert.ok(callbackCalled);
    });
  }
);

discourseModule(
  "Unit | Model | private-message-topic-tracking-state | processing new_topic message",
  function (hooks) {
    let pmTopicTrackingState;

    hooks.beforeEach(async function () {
      setupPretender();
      pmTopicTrackingState = PrivateMessageTopicTrackingState.create({
        messageBus: MessageBus,
        currentUser: User.create({ id: 77889, username: "test" }),
      });
      await pmTopicTrackingState.startTracking();
    });

    test("modifies the topic state only if the topic was not created by the current user", async function (assert) {
      let payload = {
        last_read_post_number: null,
        highest_post_number: 1,
        group_ids: [],
        created_by_user_id: 5,
      };
      await publishToMessageBus(
        "/private-message-topic-tracking-state/user/77889",
        {
          message_type: "new_topic",
          topic_id: 4398,
          payload,
        }
      );
      assert.deepEqual(
        pmTopicTrackingState.findState(4398),
        payload,
        "the new topic created by a different user is loaded into state"
      );

      payload = {
        last_read_post_number: null,
        highest_post_number: 1,
        group_ids: [],
        created_by_user_id: 77889,
      };
      await publishToMessageBus(
        "/private-message-topic-tracking-state/user/77889",
        {
          message_type: "new_topic",
          topic_id: 4400,
          payload,
        }
      );
      assert.deepEqual(
        pmTopicTrackingState.findState(4400),
        undefined,
        "the new topic created by the current user is not loaded into state"
      );
    });
  }
);

discourseModule(
  "Unit | Model | private-message-topic-tracking-state | processing unread message",
  function (hooks) {
    let pmTopicTrackingState;

    hooks.beforeEach(async function () {
      setupPretender();
      pmTopicTrackingState = PrivateMessageTopicTrackingState.create({
        messageBus: MessageBus,
        currentUser: User.create({ id: 77889, username: "test" }),
      });
      await pmTopicTrackingState.startTracking();
    });

    test("modifies the last_read_post_number and highest_post_number", async function (assert) {
      let payload = {
        last_read_post_number: 12,
        highest_post_number: 13,
        notification_level: 3,
        group_ids: [],
        created_by_user_id: 5,
      };
      await publishToMessageBus(
        "/private-message-topic-tracking-state/user/77889",
        {
          message_type: "unread",
          topic_id: 123,
          payload,
        }
      );

      let state = pmTopicTrackingState.findState(123);
      assert.deepEqual(
        state.highest_post_number,
        13,
        "the unread payload triggered by a different user creating a new post updates the state with the correct highest_post_number"
      );
      assert.deepEqual(
        state.last_read_post_number,
        12,
        "the unread payload triggered by a different user creating a new post updates the state with the correct last_read_post_number"
      );

      payload = {
        last_read_post_number: 14,
        highest_post_number: 14,
        notification_level: 3,
        group_ids: [],
        created_by_user_id: 77889,
      };
      await publishToMessageBus(
        "/private-message-topic-tracking-state/user/77889",
        {
          message_type: "unread",
          topic_id: 123,
          payload,
        }
      );

      state = pmTopicTrackingState.findState(123);
      assert.deepEqual(
        state.highest_post_number,
        14,
        "the unread payload triggered by the current user creating a new post updates the state with the correct highest_post_number"
      );
      assert.deepEqual(
        state.last_read_post_number,
        14,
        "the unread payload triggered by the current user creating a new post updates the state with the correct last_read_post_number"
      );
    });
  }
);
