import { test } from "qunit";
import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import MessageBus from "message-bus-client";
import PrivateMessageTopicTrackingState from "discourse/models/private-message-topic-tracking-state";
import User from "discourse/models/user";

discourseModule(
  "Unit | Model | private-message-topic-tracking-state",
  function (hooks) {
    let pmTopicTrackingState;

    hooks.beforeEach(function () {
      pmTopicTrackingState = PrivateMessageTopicTrackingState.create({
        messageBus: MessageBus,
        currentUser: User.create({ id: 1, username: "test" }),
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
