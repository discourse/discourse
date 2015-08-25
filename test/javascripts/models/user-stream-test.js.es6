import { blank, present } from 'helpers/qunit-helpers';

module("Discourse.UserStream");

test('basics', function(){
  var user = Discourse.User.create({id: 1, username: 'eviltrout'});
  var stream = user.get('stream');
  present(stream, "a user has a stream by default");
  equal(stream.get('user'), user, "the stream points back to the user");

  equal(stream.get('itemsLoaded'), 0, "no items are loaded by default");
  blank(stream.get('content'), "no content by default");
  blank(stream.get('filter'), "no filter by default");

  ok(!stream.get('loaded'), "the stream is not loaded by default");
});


test('filterParam', function() {
  var user = Discourse.User.create({id: 1, username: 'eviltrout'});
  var stream = user.get('stream');

  // defaults to posts/topics
  equal(stream.get('filterParam'), "4,5");

  stream.set('filter', Discourse.UserAction.TYPES.likes_given);
  equal(stream.get('filterParam'), Discourse.UserAction.TYPES.likes_given);

  stream.set('filter', Discourse.UserAction.TYPES.replies);
  equal(stream.get('filterParam'), '6,9');

});
