import Session from "discourse/models/session";

QUnit.module("model:session");

QUnit.test("highestSeenByTopic", assert => {
  const session = Session.current();
  assert.deepEqual(
    session.get("highestSeenByTopic"),
    {},
    "by default it returns an empty object"
  );
});
