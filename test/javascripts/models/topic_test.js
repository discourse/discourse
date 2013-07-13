module("Discourse.Topic");

test("defaults", function() {
  var topic = Discourse.Topic.create({id: 1234});
  blank(topic.get('deleted_at'), 'deleted_at defaults to blank');
  blank(topic.get('deleted_by'), 'deleted_by defaults to blank');
});

test('has details', function() {
  var topic = Discourse.Topic.create({id: 1234});
  var topicDetails = topic.get('details');
  present(topicDetails, "a topic has topicDetails after we create it");
  equal(topicDetails.get('topic'), topic, "the topicDetails has a reference back to the topic");
});

test('has a postStream', function() {
  var topic = Discourse.Topic.create({id: 1234});
  var postStream = topic.get('postStream');
  present(postStream, "a topic has a postStream after we create it");
  equal(postStream.get('topic'), topic, "the postStream has a reference back to the topic");
});

var category = _.first(Discourse.Category.list());

test('category relationship', function() {
  // It finds the category by id
  var topic = Discourse.Topic.create({id: 1111, category_id: category.get('id') });
  equal(topic.get('category'), category);
});

test("updateFromJson", function() {
  var topic = Discourse.Topic.create({id: 1234});

  topic.updateFromJson({
    post_stream: [1,2,3],
    details: {hello: 'world'},
    cool: 'property',
    category_id: category.get('id')
  });

  blank(topic.get('post_stream'), "it does not update post_stream");
  equal(topic.get('details.hello'), 'world', 'it updates the details');
  equal(topic.get('cool'), "property", "it updates other properties");
  equal(topic.get('category'), category);
});

test("destroy", function() {
  var user = Discourse.User.create({username: 'eviltrout'});
  var topic = Discourse.Topic.create({id: 1234});

  this.stub(Discourse, 'ajax');

  topic.destroy(user);
  present(topic.get('deleted_at'), 'deleted at is set');
  equal(topic.get('deleted_by'), user, 'deleted by is set');
  //ok(Discourse.ajax.calledOnce, "it called delete over the wire");
});

test("recover", function() {
  var user = Discourse.User.create({username: 'eviltrout'});
  var topic = Discourse.Topic.create({id: 1234, deleted_at: new Date(), deleted_by: user});

  this.stub(Discourse, 'ajax');

  topic.recover();
  blank(topic.get('deleted_at'), "it clears deleted_at");
  blank(topic.get('deleted_by'), "it clears deleted_by");
  //ok(Discourse.ajax.calledOnce, "it called recover over the wire");
});