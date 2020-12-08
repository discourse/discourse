import { module, test } from "qunit";
import Session from "discourse/models/session";

module("Unit | Model | session", function () {
  test("highestSeenByTopic", function (assert) {
    const session = Session.current();
    assert.deepEqual(
      session.get("highestSeenByTopic"),
      {},
      "by default it returns an empty object"
    );
  });
});
