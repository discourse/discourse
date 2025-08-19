import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import MessageBus from "message-bus-client";
import { module, test } from "qunit";
import PrivateMessageTopicTrackingState from "discourse/services/pm-topic-tracking-state";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { publishToMessageBus } from "discourse/tests/helpers/qunit-helpers";

function setupPretender() {
  pretender.get(`/u/test/private-message-topic-tracking-state`, () => {
    return response([
      {
        topic_id: 123,
        highest_post_number: 12,
        last_read_post_number: 12,
        notification_level: 3,
        group_ids: [],
      },
    ]);
  });
}

module("Unit | Model | private-message-topic-tracking-state", function (hooks) {
  setupTest(hooks);

  test("modifying state calls onStateChange callbacks", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const pmTopicTrackingState = PrivateMessageTopicTrackingState.create({
      messageBus: MessageBus,
      currentUser: store.createRecord("user", { id: 77889, username: "test" }),
    });

    let callbackCalled = false;

    pmTopicTrackingState.onStateChange("testing", () => {
      callbackCalled = true;
    });

    pmTopicTrackingState.set("isTracking", true);
    pmTopicTrackingState.removeTopics([]);

    assert.true(callbackCalled);
  });
});

module(
  "Unit | Model | private-message-topic-tracking-state | processing new_topic message",
  function (hooks) {
    setupTest(hooks);

    test("modifies the topic state only if the topic was not created by the current user", async function (assert) {
      setupPretender();
      const store = getOwner(this).lookup("service:store");
      const pmTopicTrackingState = PrivateMessageTopicTrackingState.create({
        messageBus: MessageBus,
        currentUser: store.createRecord("user", {
          id: 77889,
          username: "test",
        }),
      });
      await pmTopicTrackingState.startTracking();

      const payload = {
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

      const payload2 = {
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
          payload: payload2,
        }
      );
      assert.strictEqual(
        pmTopicTrackingState.findState(4400),
        undefined,
        "the new topic created by the current user is not loaded into state"
      );
    });
  }
);

module(
  "Unit | Model | private-message-topic-tracking-state | processing unread message",
  function (hooks) {
    setupTest(hooks);

    test("modifies the last_read_post_number and highest_post_number", async function (assert) {
      setupPretender();
      const store = getOwner(this).lookup("service:store");
      const pmTopicTrackingState = PrivateMessageTopicTrackingState.create({
        messageBus: MessageBus,
        currentUser: store.createRecord("user", {
          id: 77889,
          username: "test",
        }),
      });
      await pmTopicTrackingState.startTracking();

      const payload = {
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

      const state = pmTopicTrackingState.findState(123);
      assert.strictEqual(
        state.highest_post_number,
        13,
        "the unread payload triggered by a different user creating a new post updates the state with the correct highest_post_number"
      );
      assert.strictEqual(
        state.last_read_post_number,
        12,
        "the unread payload triggered by a different user creating a new post updates the state with the correct last_read_post_number"
      );

      const payload2 = {
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
          payload: payload2,
        }
      );

      const state2 = pmTopicTrackingState.findState(123);
      assert.strictEqual(
        state2.highest_post_number,
        14,
        "the unread payload triggered by the current user creating a new post updates the state with the correct highest_post_number"
      );
      assert.strictEqual(
        state2.last_read_post_number,
        14,
        "the unread payload triggered by the current user creating a new post updates the state with the correct last_read_post_number"
      );
    });
  }
);
