QUnit.module("model:topic-details");

import Topic from 'discourse/models/topic';

var buildDetails = function(id) {
  var topic = Topic.create({id: id});
  return topic.get('details');
};

QUnit.test('defaults', assert => {
  var details = buildDetails(1234);
  assert.present(details, "the details are present by default");
  assert.ok(!details.get('loaded'), "details are not loaded by default");
});

QUnit.test('updateFromJson', assert => {
  var details = buildDetails(1234);

  details.updateFromJson({
    suggested_topics: [{id: 1}, {id: 3}],
    allowed_users: [{username: 'eviltrout'}]
  });

  assert.equal(details.get('suggested_topics.length'), 2, 'it loaded the suggested_topics');
  assert.containsInstance(details.get('suggested_topics'), Topic);

  assert.equal(details.get('allowed_users.length'), 1, 'it loaded the allowed users');
  assert.containsInstance(details.get('allowed_users'), Discourse.User);

});
