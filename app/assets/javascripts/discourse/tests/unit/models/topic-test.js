import Category from "discourse/models/category";
import Topic from "discourse/models/topic";
import User from "discourse/models/user";
import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { IMAGE_VERSION as v } from "pretty-text/emoji/version";
import createStore from "discourse/tests/helpers/create-store";

discourseModule("Unit | Model | topic", function () {
  test("defaults", function (assert) {
    const topic = Topic.create({ id: 1234 });

    assert.blank(topic.get("deleted_at"), "deleted_at defaults to blank");
    assert.blank(topic.get("deleted_by"), "deleted_by defaults to blank");
  });

  test("visited", function (assert) {
    const topic = Topic.create({
      highest_post_number: 2,
      last_read_post_number: 1,
    });

    assert.notOk(
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

  test("lastUnreadUrl", function (assert) {
    const store = createStore();
    const category = store.createRecord("category", {
      id: 22,
      navigate_to_first_post_after_read: true,
    });

    const topic = Topic.create({
      id: 101,
      highest_post_number: 10,
      last_read_post_number: 10,
      slug: "hello",
      category_id: category.id,
    });

    assert.strictEqual(topic.get("lastUnreadUrl"), "/t/hello/101/1");
  });

  test("has details", function (assert) {
    const topic = Topic.create({ id: 1234 });
    const topicDetails = topic.get("details");

    assert.present(topicDetails, "a topic has topicDetails after we create it");
    assert.strictEqual(
      topicDetails.get("topic"),
      topic,
      "the topicDetails has a reference back to the topic"
    );
  });

  test("has a postStream", function (assert) {
    const topic = Topic.create({ id: 1234 });
    const postStream = topic.get("postStream");

    assert.present(postStream, "a topic has a postStream after we create it");
    assert.strictEqual(
      postStream.get("topic"),
      topic,
      "the postStream has a reference back to the topic"
    );
  });

  test("has suggestedTopics", function (assert) {
    const topic = Topic.create({ suggested_topics: [{ id: 1 }, { id: 2 }] });
    const suggestedTopics = topic.get("suggestedTopics");

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
    const topic = Topic.create({ id: 1111, category_id: category.get("id") });

    assert.strictEqual(topic.get("category"), category);
  });

  test("updateFromJson", function (assert) {
    const topic = Topic.create({ id: 1234 });
    const category = Category.list()[0];

    topic.updateFromJson({
      post_stream: [1, 2, 3],
      details: { hello: "world" },
      cool: "property",
      category_id: category.get("id"),
    });

    assert.blank(topic.get("post_stream"), "it does not update post_stream");
    assert.strictEqual(
      topic.get("details.hello"),
      "world",
      "it updates the details"
    );
    assert.strictEqual(
      topic.get("cool"),
      "property",
      "it updates other properties"
    );
    assert.strictEqual(topic.get("category"), category);
  });

  test("recover", async function (assert) {
    const user = User.create({ username: "eviltrout" });
    const topic = Topic.create({
      id: 1234,
      deleted_at: new Date(),
      deleted_by: user,
    });

    await topic.recover();

    assert.blank(topic.get("deleted_at"), "it clears deleted_at");
    assert.blank(topic.get("deleted_by"), "it clears deleted_by");
  });

  test("fancyTitle", function (assert) {
    const topic = Topic.create({
      fancy_title: ":smile: with all :) the emojis :pear::peach:",
    });

    assert.strictEqual(
      topic.get("fancyTitle"),
      `<img width=\"20\" height=\"20\" src='/images/emoji/google_classic/smile.png?v=${v}' title='smile' alt='smile' class='emoji'> with all <img width=\"20\" height=\"20\" src='/images/emoji/google_classic/slight_smile.png?v=${v}' title='slight_smile' alt='slight_smile' class='emoji'> the emojis <img width=\"20\" height=\"20\" src='/images/emoji/google_classic/pear.png?v=${v}' title='pear' alt='pear' class='emoji'><img width=\"20\" height=\"20\" src='/images/emoji/google_classic/peach.png?v=${v}' title='peach' alt='peach' class='emoji'>`,
      "supports emojis"
    );
  });

  test("fancyTitle direction", function (assert) {
    const rtlTopic = Topic.create({ fancy_title: "هذا اختبار" });
    const ltrTopic = Topic.create({ fancy_title: "This is a test" });

    this.siteSettings.support_mixed_text_direction = true;
    assert.strictEqual(
      rtlTopic.get("fancyTitle"),
      `<span dir="rtl">هذا اختبار</span>`,
      "sets the dir-span to rtl"
    );
    assert.strictEqual(
      ltrTopic.get("fancyTitle"),
      `<span dir="ltr">This is a test</span>`,
      "sets the dir-span to ltr"
    );
  });

  test("excerpt", function (assert) {
    const topic = Topic.create({
      excerpt: "This is a test topic :smile:",
      pinned: true,
    });

    assert.strictEqual(
      topic.get("escapedExcerpt"),
      `This is a test topic <img width=\"20\" height=\"20\" src='/images/emoji/google_classic/smile.png?v=${v}' title='smile' alt='smile' class='emoji'>`,
      "supports emojis"
    );
  });

  test("visible & invisible", function (assert) {
    const topic = Topic.create();
    assert.strictEqual(topic.visible, undefined);
    assert.strictEqual(topic.invisible, undefined);

    const visibleTopic = Topic.create({ visible: true });
    assert.strictEqual(visibleTopic.visible, true);
    assert.strictEqual(visibleTopic.invisible, false);

    const invisibleTopic = Topic.create({ visible: false });
    assert.strictEqual(invisibleTopic.visible, false);
    assert.strictEqual(invisibleTopic.invisible, true);
  });
});
