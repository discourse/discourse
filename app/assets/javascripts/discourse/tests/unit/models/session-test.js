import { test, module } from "qunit";
import Session from "discourse/models/session";

module("model:session");

test("highestSeenByTopic", (assert) => {
  const session = Session.current();
  assert.deepEqual(
    session.get("highestSeenByTopic"),
    {},
    "by default it returns an empty object"
  );
});
