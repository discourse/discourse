import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { IMAGE_VERSION as v } from "pretty-text/emoji/version";
import { module, test } from "qunit";
import Category from "discourse/models/category";
import Topic from "discourse/models/topic";
import TopicDetails from "discourse/models/topic-details";

module("Unit | Model | topic", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.store = getOwner(this).lookup("service:store");
  });

  test("defaults", function (assert) {
    const topic = this.store.createRecord("topic", { id: 1234 });

    assert.blank(topic.deleted_at, "deleted_at defaults to blank");
    assert.blank(topic.deleted_by, "deleted_by defaults to blank");
  });

  test("visited", function (assert) {
    const topic = this.store.createRecord("topic", {
      highest_post_number: 2,
      last_read_post_number: 1,
    });

    assert.false(topic.visited, "not visited unless we've read all the posts");

    topic.set("last_read_post_number", 2);
    assert.true(topic.visited, "is visited once we've read all the posts");

    topic.set("last_read_post_number", 3);
    assert.true(
      topic.visited,
      "is visited if we've read all the posts and some are deleted at the end"
    );
  });

  test("lastUnreadUrl when user read the whole topic", function (assert) {
    const topic = this.store.createRecord("topic", {
      id: 101,
      highest_post_number: 10,
      last_read_post_number: 10,
      slug: "hello",
    });

    assert.strictEqual(topic.lastUnreadUrl, "/t/hello/101/10");
  });

  test("lastUnreadUrl when there are unread posts", function (assert) {
    const topic = this.store.createRecord("topic", {
      id: 101,
      highest_post_number: 10,
      last_read_post_number: 5,
      slug: "hello",
    });

    assert.strictEqual(topic.lastUnreadUrl, "/t/hello/101/6");
  });

  test("lastUnreadUrl when last_read_post_number is incorrect", function (assert) {
    const topic = this.store.createRecord("topic", {
      id: 101,
      highest_post_number: 10,
      last_read_post_number: 15,
      slug: "hello",
    });

    assert.strictEqual(topic.lastUnreadUrl, "/t/hello/101/10");
  });

  test("lastUnreadUrl with navigate_to_first_post_after_read setting", function (assert) {
    const category = this.store.createRecord("category", {
      id: 22,
      navigate_to_first_post_after_read: true,
    });

    const topic = this.store.createRecord("topic", {
      id: 101,
      highest_post_number: 10,
      last_read_post_number: 10,
      slug: "hello",
      category_id: category.id,
    });

    assert.strictEqual(topic.lastUnreadUrl, "/t/hello/101/1");
  });

  test("lastUnreadUrl with navigate_to_first_post_after_read setting and unread posts", function (assert) {
    const category = this.store.createRecord("category", {
      id: 22,
      navigate_to_first_post_after_read: true,
    });

    const topic = this.store.createRecord("topic", {
      id: 101,
      highest_post_number: 10,
      last_read_post_number: 5,
      slug: "hello",
      category_id: category.id,
    });

    assert.strictEqual(topic.lastUnreadUrl, "/t/hello/101/6");
  });

  test("has details", function (assert) {
    const topic = this.store.createRecord("topic", { id: 1234 });
    const topicDetails = topic.details;

    assert.true(
      topicDetails instanceof TopicDetails,
      "topicDetails is an instance of TopicDetails"
    );
    assert.present(topicDetails, "a topic has topicDetails after we create it");
    assert.strictEqual(
      topicDetails.topic,
      topic,
      "the topicDetails has a reference back to the topic"
    );
  });

  test("has a postStream", function (assert) {
    const topic = this.store.createRecord("topic", { id: 1234 });
    const postStream = topic.postStream;

    assert.present(postStream, "a topic has a postStream after we create it");
    assert.strictEqual(
      postStream.topic,
      topic,
      "the postStream has a reference back to the topic"
    );
  });

  test("has suggestedTopics", function (assert) {
    const topic = this.store.createRecord("topic", {
      suggested_topics: [{ id: 1 }, { id: 2 }],
    });
    const suggestedTopics = topic.suggestedTopics;

    assert.strictEqual(
      suggestedTopics.length,
      2,
      "it loaded the suggested_topics"
    );
    assert.containsInstance(suggestedTopics, Topic);
  });

  test("category relationship", function (assert) {
    // It finds the category by id
    const category = Category.list()[0];
    const topic = this.store.createRecord("topic", {
      id: 1111,
      category_id: category.id,
    });

    assert.strictEqual(topic.category, category);
  });

  test("updateFromJson", function (assert) {
    const topic = this.store.createRecord("topic", { id: 1234 });
    const category = Category.list()[0];

    topic.updateFromJson({
      post_stream: [1, 2, 3],
      details: { hello: "world" },
      cool: "property",
      category_id: category.id,
    });

    assert.blank(topic.post_stream, "it does not update post_stream");
    assert.true(
      topic.details instanceof TopicDetails,
      "topicDetails is an instance of TopicDetails"
    );
    assert.strictEqual(topic.details.hello, "world", "it updates the details");
    assert.strictEqual(topic.cool, "property", "it updates other properties");
    assert.strictEqual(topic.category, category);
  });

  test("recover", async function (assert) {
    const user = this.store.createRecord("user", { username: "eviltrout" });
    const topic = this.store.createRecord("topic", {
      id: 1234,
      deleted_at: new Date(),
      deleted_by: user,
    });

    await topic.recover();

    assert.blank(topic.deleted_at, "it clears deleted_at");
    assert.blank(topic.deleted_by, "it clears deleted_by");
  });

  test("fancyTitle", function (assert) {
    const topic = this.store.createRecord("topic", {
      fancy_title: ":smile: with all :) the emojis :pear::peach:",
    });

    assert.strictEqual(
      topic.fancyTitle,
      `<img width=\"20\" height=\"20\" src='/images/emoji/twitter/smile.png?v=${v}' title='smile' alt='smile' class='emoji'> with all <img width=\"20\" height=\"20\" src='/images/emoji/twitter/slight_smile.png?v=${v}' title='slight_smile' alt='slight_smile' class='emoji'> the emojis <img width=\"20\" height=\"20\" src='/images/emoji/twitter/pear.png?v=${v}' title='pear' alt='pear' class='emoji'><img width=\"20\" height=\"20\" src='/images/emoji/twitter/peach.png?v=${v}' title='peach' alt='peach' class='emoji'>`,
      "supports emojis"
    );
  });

  test("fancyTitle direction", function (assert) {
    const rtlTopic = this.store.createRecord("topic", {
      fancy_title: "هذا اختبار",
    });
    const ltrTopic = this.store.createRecord("topic", {
      fancy_title: "This is a test",
    });

    const siteSettings = getOwner(this).lookup("service:site-settings");
    siteSettings.support_mixed_text_direction = true;

    assert.strictEqual(
      rtlTopic.fancyTitle,
      `<span dir="auto">هذا اختبار</span>`,
      "sets the dir-span to auto"
    );
    assert.strictEqual(
      ltrTopic.fancyTitle,
      `<span dir="auto">This is a test</span>`,
      "sets the dir-span to auto"
    );
  });

  test("excerpt", function (assert) {
    const topic = this.store.createRecord("topic", {
      excerpt: "This is a test topic :smile:",
      pinned: true,
    });

    assert.strictEqual(
      topic.escapedExcerpt,
      `This is a test topic <img width=\"20\" height=\"20\" src='/images/emoji/twitter/smile.png?v=${v}' title='smile' alt='smile' class='emoji'>`,
      "supports emojis"
    );
  });

  test("visible & invisible", function (assert) {
    const topic = this.store.createRecord("topic");
    assert.strictEqual(topic.visible, undefined);
    assert.strictEqual(topic.invisible, undefined);

    const visibleTopic = this.store.createRecord("topic", { visible: true });
    assert.true(visibleTopic.visible);
    assert.false(visibleTopic.invisible);

    const invisibleTopic = this.store.createRecord("topic", { visible: false });
    assert.false(invisibleTopic.visible);
    assert.true(invisibleTopic.invisible);
  });
});
