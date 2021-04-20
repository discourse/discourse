import {
  CREATE_TOPIC,
  EDIT,
  PRIVATE_MESSAGE,
  REPLY,
} from "discourse/models/composer";
import {
  currentUser,
  discourseModule,
} from "discourse/tests/helpers/qunit-helpers";
import AppEvents from "discourse/services/app-events";
import EmberObject from "@ember/object";
import Post from "discourse/models/post";
import createStore from "discourse/tests/helpers/create-store";
import { test } from "qunit";

function createComposer(opts) {
  opts = opts || {};
  opts.user = opts.user || currentUser();
  opts.appEvents = AppEvents.create();
  return createStore().createRecord("composer", opts);
}

function openComposer(opts) {
  const composer = createComposer(opts);
  composer.open(opts);
  return composer;
}

discourseModule("Unit | Model | composer", function () {
  test("replyLength", function (assert) {
    const replyLength = function (val, expectedLength) {
      const composer = createComposer({ reply: val });
      assert.equal(composer.get("replyLength"), expectedLength);
    };

    replyLength("basic reply", 11, "basic reply length");
    replyLength(" \nbasic reply\t", 11, "trims whitespaces");
    replyLength("ba sic\n\nreply", 12, "count only significant whitespaces");
    replyLength(
      "1[quote=]not counted[/quote]2[quote=]at all[/quote]3",
      3,
      "removes quotes"
    );
    replyLength(
      "1[quote=]not[quote=]counted[/quote]yay[/quote]2",
      2,
      "handles nested quotes correctly"
    );
    replyLength("<!-- a comment -->", 0, "remove comments");

    replyLength(
      "<!-- a comment -->\n more text \n<!-- a comment -->",
      9,
      "remove multiple comments"
    );

    replyLength(
      "<!-- <!-- a comment --> -->more text",
      12,
      "remove multiple comments"
    );
  });

  test("missingReplyCharacters", function (assert) {
    this.siteSettings.min_first_post_length = 40;
    const missingReplyCharacters = function (
      val,
      isPM,
      isFirstPost,
      expected,
      message
    ) {
      let action = REPLY;
      if (isPM) {
        action = PRIVATE_MESSAGE;
      }
      if (isFirstPost) {
        action = CREATE_TOPIC;
      }
      const composer = createComposer({ reply: val, action });
      assert.equal(composer.get("missingReplyCharacters"), expected, message);
    };

    missingReplyCharacters(
      "hi",
      false,
      false,
      this.siteSettings.min_post_length - 2,
      "too short public post"
    );
    missingReplyCharacters(
      "hi",
      false,
      true,
      this.siteSettings.min_first_post_length - 2,
      "too short first post"
    );
    missingReplyCharacters(
      "hi",
      true,
      false,
      this.siteSettings.min_personal_message_post_length - 2,
      "too short private message"
    );

    const link = "http://imgur.com/gallery/grxX8";
    this.siteSettings.topic_featured_link_enabled = true;
    this.siteSettings.topic_featured_link_allowed_category_ids = 12345;
    const composer = createComposer({
      title: link,
      categoryId: 12345,
      featuredLink: link,
      action: CREATE_TOPIC,
      reply: link,
    });

    assert.equal(
      composer.get("missingReplyCharacters"),
      0,
      "don't require any post content"
    );
  });

  test("missingTitleCharacters", function (assert) {
    const missingTitleCharacters = function (val, isPM, expected, message) {
      const composer = createComposer({
        title: val,
        action: isPM ? PRIVATE_MESSAGE : REPLY,
      });
      assert.equal(composer.get("missingTitleCharacters"), expected, message);
    };

    missingTitleCharacters(
      "hi",
      false,
      this.siteSettings.min_topic_title_length - 2,
      "too short post title"
    );
    missingTitleCharacters(
      "z",
      true,
      this.siteSettings.min_personal_message_title_length - 1,
      "too short pm title"
    );
  });

  test("replyDirty", function (assert) {
    const composer = createComposer();
    assert.ok(!composer.get("replyDirty"), "by default it's false");

    composer.setProperties({
      originalText: "hello",
      reply: "hello",
    });

    assert.ok(
      !composer.get("replyDirty"),
      "it's false when the originalText is the same as the reply"
    );
    composer.set("reply", "hello world");
    assert.ok(composer.get("replyDirty"), "it's true when the reply changes");
  });

  test("appendText", function (assert) {
    const composer = createComposer();

    assert.blank(composer.get("reply"), "the reply is blank by default");

    composer.appendText("hello");
    assert.equal(composer.get("reply"), "hello", "it appends text to nothing");
    composer.appendText(" world");
    assert.equal(
      composer.get("reply"),
      "hello world",
      "it appends text to existing text"
    );

    composer.clearState();
    composer.appendText("a\n\n\n\nb");
    composer.appendText("c", 3, { block: true });

    assert.equal(composer.get("reply"), "a\n\nc\n\nb");

    composer.clearState();
    composer.appendText("ab");
    composer.appendText("c", 1, { block: true });

    assert.equal(composer.get("reply"), "a\n\nc\n\nb");

    composer.clearState();
    composer.appendText("\nab");
    composer.appendText("c", 0, { block: true });

    assert.equal(composer.get("reply"), "c\n\nab");
  });

  test("prependText", function (assert) {
    const composer = createComposer();

    assert.blank(composer.get("reply"), "the reply is blank by default");

    composer.prependText("hello");
    assert.equal(composer.get("reply"), "hello", "it prepends text to nothing");

    composer.prependText("world ");
    assert.equal(
      composer.get("reply"),
      "world hello",
      "it prepends text to existing text"
    );

    composer.prependText("before new line", { new_line: true });
    assert.equal(
      composer.get("reply"),
      "before new line\n\nworld hello",
      "it prepends text with new line to existing text"
    );
  });

  test("Title length for regular topics", function (assert) {
    this.siteSettings.min_topic_title_length = 5;
    this.siteSettings.max_topic_title_length = 10;
    const composer = createComposer();

    composer.set("title", "asdf");
    assert.ok(!composer.get("titleLengthValid"), "short titles are not valid");

    composer.set("title", "this is a long title");
    assert.ok(!composer.get("titleLengthValid"), "long titles are not valid");

    composer.set("title", "just right");
    assert.ok(composer.get("titleLengthValid"), "in the range is okay");
  });

  test("Title length for private messages", function (assert) {
    this.siteSettings.min_personal_message_title_length = 5;
    this.siteSettings.max_topic_title_length = 10;
    const composer = createComposer({ action: PRIVATE_MESSAGE });

    composer.set("title", "asdf");
    assert.ok(!composer.get("titleLengthValid"), "short titles are not valid");

    composer.set("title", "this is a long title");
    assert.ok(!composer.get("titleLengthValid"), "long titles are not valid");

    composer.set("title", "just right");
    assert.ok(composer.get("titleLengthValid"), "in the range is okay");
  });

  test("Post length for private messages with non human users", function (assert) {
    const composer = createComposer({
      topic: EmberObject.create({ pm_with_non_human_user: true }),
    });

    assert.equal(composer.get("minimumPostLength"), 1);
  });

  test("editingFirstPost", function (assert) {
    const composer = createComposer();
    assert.ok(!composer.get("editingFirstPost"), "it's false by default");

    const post = Post.create({ id: 123, post_number: 2 });
    composer.setProperties({ post: post, action: EDIT });
    assert.ok(
      !composer.get("editingFirstPost"),
      "it's false when not editing the first post"
    );

    post.set("post_number", 1);
    assert.ok(
      composer.get("editingFirstPost"),
      "it's true when editing the first post"
    );
  });

  test("clearState", function (assert) {
    const composer = createComposer({
      originalText: "asdf",
      reply: "asdf2",
      post: Post.create({ id: 1 }),
      title: "wat",
    });

    composer.clearState();

    assert.blank(composer.get("originalText"));
    assert.blank(composer.get("reply"));
    assert.blank(composer.get("post"));
    assert.blank(composer.get("title"));
  });

  test("initial category when uncategorized is allowed", function (assert) {
    this.siteSettings.allow_uncategorized_topics = true;
    const composer = openComposer({
      action: CREATE_TOPIC,
      draftKey: "asfd",
      draftSequence: 1,
    });
    assert.ok(!composer.get("categoryId"), "Uncategorized by default");
  });

  test("initial category when uncategorized is not allowed", function (assert) {
    this.siteSettings.allow_uncategorized_topics = false;
    const composer = openComposer({
      action: CREATE_TOPIC,
      draftKey: "asfd",
      draftSequence: 1,
    });
    assert.ok(
      !composer.get("categoryId"),
      "Uncategorized by default. Must choose a category."
    );
  });

  test("open with a quote", function (assert) {
    const quote =
      '[quote="neil, post:5, topic:413"]\nSimmer down you two.\n[/quote]';
    const newComposer = function () {
      return openComposer({
        action: REPLY,
        draftKey: "asfd",
        draftSequence: 1,
        quote: quote,
      });
    };

    assert.equal(
      newComposer().get("originalText"),
      quote,
      "originalText is the quote"
    );
    assert.equal(
      newComposer().get("replyDirty"),
      false,
      "replyDirty is initially false with a quote"
    );
  });

  test("Title length for static page topics as admin", function (assert) {
    this.siteSettings.min_topic_title_length = 5;
    this.siteSettings.max_topic_title_length = 10;
    const composer = createComposer();

    const post = Post.create({
      id: 123,
      post_number: 2,
      static_doc: true,
    });
    composer.setProperties({ post: post, action: EDIT });

    composer.set("title", "asdf");
    assert.ok(composer.get("titleLengthValid"), "admins can use short titles");

    composer.set("title", "this is a long title");
    assert.ok(composer.get("titleLengthValid"), "admins can use long titles");

    composer.set("title", "just right");
    assert.ok(composer.get("titleLengthValid"), "in the range is okay");

    composer.set("title", "");
    assert.ok(
      !composer.get("titleLengthValid"),
      "admins must set title to at least 1 character"
    );
  });

  test("title placeholder depends on what you're doing", function (assert) {
    let composer = createComposer({ action: CREATE_TOPIC });
    assert.equal(
      composer.get("titlePlaceholder"),
      "composer.title_placeholder",
      "placeholder for normal topic"
    );

    composer = createComposer({ action: PRIVATE_MESSAGE });
    assert.equal(
      composer.get("titlePlaceholder"),
      "composer.title_placeholder",
      "placeholder for private message"
    );

    this.siteSettings.topic_featured_link_enabled = true;

    composer = createComposer({ action: CREATE_TOPIC });
    assert.equal(
      composer.get("titlePlaceholder"),
      "composer.title_or_link_placeholder",
      "placeholder invites you to paste a link"
    );

    composer = createComposer({ action: PRIVATE_MESSAGE });
    assert.equal(
      composer.get("titlePlaceholder"),
      "composer.title_placeholder",
      "placeholder for private message with topic links enabled"
    );
  });

  test("allows featured link before choosing a category", function (assert) {
    this.siteSettings.topic_featured_link_enabled = true;
    this.siteSettings.allow_uncategorized_topics = false;
    let composer = createComposer({ action: CREATE_TOPIC });
    assert.equal(
      composer.get("titlePlaceholder"),
      "composer.title_or_link_placeholder",
      "placeholder invites you to paste a link"
    );
    assert.ok(composer.get("canEditTopicFeaturedLink"), "can paste link");
  });

  test("targetRecipientsArray contains types", function (assert) {
    let composer = createComposer({
      targetRecipients: "test,codinghorror,staff,foo@bar.com",
    });
    assert.ok(composer.targetRecipientsArray, [
      { type: "group", name: "test" },
      { type: "user", name: "codinghorror" },
      { type: "group", name: "staff" },
      { type: "email", name: "foo@bar.com" },
    ]);
  });
});
