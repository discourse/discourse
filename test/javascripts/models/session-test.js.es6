import Session from "discourse/models/session";

module("Discourse.Session");

test('highestSeenByTopic', function() {
  var session = Session.current();
  deepEqual(session.get('highestSeenByTopic'), {}, "by default it returns an empty object");
});
