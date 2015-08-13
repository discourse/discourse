import Session from "discourse/models/session";

module("model:session");

test('highestSeenByTopic', function() {
  const session = Session.current();
  deepEqual(session.get('highestSeenByTopic'), {}, "by default it returns an empty object");
});
