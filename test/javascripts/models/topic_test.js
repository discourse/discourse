module("Discourse.Topic");

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