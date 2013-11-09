module("Discourse.Session");

test('highestSeenByTopic', function() {
  var session = Discourse.Session.current();
  deepEqual(session.get('highestSeenByTopic'), {}, "by default it returns an empty object");
});