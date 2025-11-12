import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import Session from "discourse/models/session";

module("Unit | Model | session", function (hooks) {
  setupTest(hooks);

  test("highestSeenByTopic", function (assert) {
    const session = Session.current();
    assert.deepEqual(
      session.get("highestSeenByTopic"),
      {},
      "by default it returns an empty object"
    );
  });
});
