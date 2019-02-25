import { IMAGE_VERSION as v } from "pretty-text/emoji";

QUnit.module("model:topic");

import Topic from "discourse/models/topic";

QUnit.test("defaults", assert => {
  const topic = Topic.create({ id: 1234 });

  assert.blank(topic.get("deleted_at"), "deleted_at defaults to blank");
  assert.blank(topic.get("deleted_by"), "deleted_by defaults to blank");
});

QUnit.test("visited", assert => {
  const topic = Topic.create({
    highest_post_number: 2,
    last_read_post_number: 1
  });

  assert.not(
    topic.get("visited"),
    "not visited unless we've read all the posts"
  );

  topic.set("last_read_post_number", 2);
  assert.ok(topic.get("visited"), "is visited once we've read all the posts");

  topic.set("last_read_post_number", 3);
  assert.ok(
    topic.get("visited"),
    "is visited if we've read all the posts and some are deleted at the end"
  );
});

QUnit.test("lastUnreadUrl", assert => {
  const category = Ember.Object.create({
    navigate_to_first_post_after_read: true
  });

  const topic = Topic.create({
    id: 101,
    highest_post_number: 10,
    last_read_post_number: 10,
    slug: "hello"
  });

  topic.set("category", category);

  assert.equal(topic.get("lastUnreadUrl"), "/t/hello/101/1");
});

QUnit.test("has details", assert => {
  const topic = Topic.create({ id: 1234 });
  const topicDetails = topic.get("details");

  assert.present(topicDetails, "a topic has topicDetails after we create it");
  assert.equal(
    topicDetails.get("topic"),
    topic,
    "the topicDetails has a reference back to the topic"
  );
});

QUnit.test("has a postStream", assert => {
  const topic = Topic.create({ id: 1234 });
  const postStream = topic.get("postStream");

  assert.present(postStream, "a topic has a postStream after we create it");
  assert.equal(
    postStream.get("topic"),
    topic,
    "the postStream has a reference back to the topic"
  );
});

QUnit.test("has suggestedTopics", assert => {
  const topic = Topic.create({ suggested_topics: [{ id: 1 }, { id: 2 }] });
  const suggestedTopics = topic.get("suggestedTopics");

  assert.equal(suggestedTopics.length, 2, "it loaded the suggested_topics");
  assert.containsInstance(suggestedTopics, Topic);
});

QUnit.test("category relationship", assert => {
  // It finds the category by id
  const category = Discourse.Category.list()[0];
  const topic = Topic.create({ id: 1111, category_id: category.get("id") });

  assert.equal(topic.get("category"), category);
});

QUnit.test("updateFromJson", assert => {
  const topic = Topic.create({ id: 1234 });
  const category = Discourse.Category.list()[0];

  topic.updateFromJson({
    post_stream: [1, 2, 3],
    details: { hello: "world" },
    cool: "property",
    category_id: category.get("id")
  });

  assert.blank(topic.get("post_stream"), "it does not update post_stream");
  assert.equal(topic.get("details.hello"), "world", "it updates the details");
  assert.equal(topic.get("cool"), "property", "it updates other properties");
  assert.equal(topic.get("category"), category);
});

QUnit.test("destroy", assert => {
  const user = Discourse.User.create({ username: "eviltrout" });
  const topic = Topic.create({ id: 1234 });

  topic.destroy(user);
  assert.present(topic.get("deleted_at"), "deleted at is set");
  assert.equal(topic.get("deleted_by"), user, "deleted by is set");
});

QUnit.test("recover", assert => {
  const user = Discourse.User.create({ username: "eviltrout" });
  const topic = Topic.create({
    id: 1234,
    deleted_at: new Date(),
    deleted_by: user
  });

  topic.recover();
  assert.blank(topic.get("deleted_at"), "it clears deleted_at");
  assert.blank(topic.get("deleted_by"), "it clears deleted_by");
});

QUnit.test("fancyTitle", assert => {
  const topic = Topic.create({
    fancy_title: ":smile: with all :) the emojis :pear::peach:"
  });

  assert.equal(
    topic.get("fancyTitle"),
    `<img src='/images/emoji/emoji_one/smile.png?v=${v}' title='smile' alt='smile' class='emoji'> with all <img src='/images/emoji/emoji_one/slight_smile.png?v=${v}' title='slight_smile' alt='slight_smile' class='emoji'> the emojis <img src='/images/emoji/emoji_one/pear.png?v=${v}' title='pear' alt='pear' class='emoji'><img src='/images/emoji/emoji_one/peach.png?v=${v}' title='peach' alt='peach' class='emoji'>`,
    "supports emojis"
  );
});

QUnit.test("fancyTitle direction", assert => {
  const rtlTopic = Topic.create({ fancy_title: "هذا اختبار" });
  const ltrTopic = Topic.create({ fancy_title: "This is a test" });

  Discourse.SiteSettings.support_mixed_text_direction = true;
  assert.equal(
    rtlTopic.get("fancyTitle"),
    `<span dir="rtl">هذا اختبار</span>`,
    "sets the dir-span to rtl"
  );
  assert.equal(
    ltrTopic.get("fancyTitle"),
    `<span dir="ltr">This is a test</span>`,
    "sets the dir-span to ltr"
  );
});

QUnit.test("excerpt", assert => {
  const topic = Topic.create({
    excerpt: "This is a test topic :smile:",
    pinned: true
  });

  assert.equal(
    topic.get("escapedExcerpt"),
    `This is a test topic <img src='/images/emoji/emoji_one/smile.png?v=${v}' title='smile' alt='smile' class='emoji'>`,
    "supports emojis"
  );
});
