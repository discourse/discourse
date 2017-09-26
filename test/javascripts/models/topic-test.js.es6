import { IMAGE_VERSION as v } from 'pretty-text/emoji';

QUnit.module("model:topic");

import Topic from 'discourse/models/topic';

QUnit.test("defaults", assert => {
  var topic = Topic.create({id: 1234});
  assert.blank(topic.get('deleted_at'), 'deleted_at defaults to blank');
  assert.blank(topic.get('deleted_by'), 'deleted_by defaults to blank');
});

QUnit.test('has details', assert => {
  var topic = Topic.create({id: 1234});
  var topicDetails = topic.get('details');
  assert.present(topicDetails, "a topic has topicDetails after we create it");
  assert.equal(topicDetails.get('topic'), topic, "the topicDetails has a reference back to the topic");
});

QUnit.test('has a postStream', assert => {
  var topic = Topic.create({id: 1234});
  var postStream = topic.get('postStream');
  assert.present(postStream, "a topic has a postStream after we create it");
  assert.equal(postStream.get('topic'), topic, "the postStream has a reference back to the topic");
});

QUnit.test('has suggestedTopics', assert => {
  const topic = Topic.create({ suggested_topics: [{ id: 1 }, { id: 2 }] });
  const suggestedTopics = topic.get('suggestedTopics');

  assert.equal(suggestedTopics.length, 2, 'it loaded the suggested_topics');
  assert.containsInstance(suggestedTopics, Topic);
});

QUnit.test('category relationship', assert => {
  // It finds the category by id
  var category = Discourse.Category.list()[0],
      topic = Topic.create({id: 1111, category_id: category.get('id') });

  assert.equal(topic.get('category'), category);
});

QUnit.test("updateFromJson", assert => {
  var topic = Topic.create({id: 1234}),
      category = Discourse.Category.list()[0];

  topic.updateFromJson({
    post_stream: [1,2,3],
    details: {hello: 'world'},
    cool: 'property',
    category_id: category.get('id')
  });

  assert.blank(topic.get('post_stream'), "it does not update post_stream");
  assert.equal(topic.get('details.hello'), 'world', 'it updates the details');
  assert.equal(topic.get('cool'), "property", "it updates other properties");
  assert.equal(topic.get('category'), category);
});

QUnit.test("destroy", assert => {
  var user = Discourse.User.create({username: 'eviltrout'});
  var topic = Topic.create({id: 1234});

  topic.destroy(user);
  assert.present(topic.get('deleted_at'), 'deleted at is set');
  assert.equal(topic.get('deleted_by'), user, 'deleted by is set');
});

QUnit.test("recover", assert => {
  var user = Discourse.User.create({username: 'eviltrout'});
  var topic = Topic.create({id: 1234, deleted_at: new Date(), deleted_by: user});

  topic.recover();
  assert.blank(topic.get('deleted_at'), "it clears deleted_at");
  assert.blank(topic.get('deleted_by'), "it clears deleted_by");
});

QUnit.test('fancyTitle', assert => {
  var topic = Topic.create({ fancy_title: ":smile: with all :) the emojis :pear::peach:" });

  assert.equal(topic.get('fancyTitle'),
        `<img src='/images/emoji/emoji_one/smile.png?v=${v}' title='smile' alt='smile' class='emoji'> with all <img src='/images/emoji/emoji_one/slight_smile.png?v=${v}' title='slight_smile' alt='slight_smile' class='emoji'> the emojis <img src='/images/emoji/emoji_one/pear.png?v=${v}' title='pear' alt='pear' class='emoji'><img src='/images/emoji/emoji_one/peach.png?v=${v}' title='peach' alt='peach' class='emoji'>`,
        "supports emojis");
});

QUnit.test('excerpt', assert => {
  var topic = Topic.create({ excerpt: "This is a test topic :smile:", pinned: true });

  assert.equal(topic.get('escapedExcerpt'),
        `This is a test topic <img src='/images/emoji/emoji_one/smile.png?v=${v}' title='smile' alt='smile' class='emoji'>`,
        "supports emojis");
});
