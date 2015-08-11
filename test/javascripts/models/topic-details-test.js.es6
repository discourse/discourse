import { present } from 'helpers/qunit-helpers';
module("model:topic-details");

import Topic from 'discourse/models/topic';

var buildDetails = function(id) {
  var topic = Topic.create({id: id});
  return topic.get('details');
};

test('defaults', function() {
  var details = buildDetails(1234);
  present(details, "the details are present by default");
  ok(!details.get('loaded'), "details are not loaded by default");
});

test('updateFromJson', function() {
  var details = buildDetails(1234);

  details.updateFromJson({
    suggested_topics: [{id: 1}, {id: 3}],
    allowed_users: [{username: 'eviltrout'}]
  });

  equal(details.get('suggested_topics.length'), 2, 'it loaded the suggested_topics');
  containsInstance(details.get('suggested_topics'), Topic);

  equal(details.get('allowed_users.length'), 1, 'it loaded the allowed users');
  containsInstance(details.get('allowed_users'), Discourse.User);

});
