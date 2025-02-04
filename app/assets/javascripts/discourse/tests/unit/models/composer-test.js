import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  CREATE_TOPIC,
  EDIT,
  PRIVATE_MESSAGE,
  REPLY,
} from "discourse/models/composer";
import pretender, {
  parsePostData,
  response,
} from "discourse/tests/helpers/create-pretender";
import { currentUser } from "discourse/tests/helpers/qunit-helpers";

function createComposer(opts = {}) {
  opts.user ??= currentUser();
  const store = getOwner(this).lookup("service:store");
  return store.createRecord("composer", opts);
}

function openComposer(opts) {
  const composer = createComposer.call(this, opts);
  composer.open(opts);
  return composer;
}

module("Unit | Model | composer", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings = getOwner(this).lookup("service:site-settings");
  });

  test("replyLength", function (assert) {
    const replyLength = (val, expectedLength) => {
      const composer = createComposer.call(this, { reply: val });
      assert.strictEqual(composer.replyLength, expectedLength);
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

    const missingReplyCharacters = (
      val,
      isPM,
      isFirstPost,
      expected,
      message
    ) => {
      let action;

      if (isFirstPost) {
        action = CREATE_TOPIC;
      } else if (isPM) {
        action = PRIVATE_MESSAGE;
      } else {
        action = REPLY;
      }

      const composer = createComposer.call(this, { reply: val, action });
      assert.strictEqual(composer.missingReplyCharacters, expected, message);
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
    const composer = createComposer.call(this, {
      title: link,
      categoryId: 12345,
      featuredLink: link,
      action: CREATE_TOPIC,
      reply: link,
    });

    assert.strictEqual(
      composer.missingReplyCharacters,
      0,
      "don't require any post content"
    );
  });

  test("missingTitleCharacters", function (assert) {
    const missingTitleCharacters = (val, isPM, expected, message) => {
      const composer = createComposer.call(this, {
        title: val,
        action: isPM ? PRIVATE_MESSAGE : REPLY,
      });
      assert.strictEqual(composer.missingTitleCharacters, expected, message);
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
    const composer = createComposer.call(this);
    assert.false(composer.replyDirty, "false by default");

    composer.setProperties({
      originalText: "hello",
      reply: "hello",
    });

    assert.false(
      composer.replyDirty,
      "false when the originalText is the same as the reply"
    );
    composer.set("reply", "hello world");
    assert.true(composer.replyDirty, "true when the reply changes");
  });

  test("appendText", function (assert) {
    const composer = createComposer.call(this);

    assert.blank(composer.reply, "the reply is blank by default");

    composer.appendText("hello");
    assert.strictEqual(composer.reply, "hello", "it appends text to nothing");
    composer.appendText(" world");
    assert.strictEqual(
      composer.reply,
      "hello world",
      "it appends text to existing text"
    );

    composer.clearState();
    composer.appendText("a\n\n\n\nb");
    composer.appendText("c", 3, { block: true });

    assert.strictEqual(composer.reply, "a\n\nc\n\nb");

    composer.clearState();
    composer.appendText("ab");
    composer.appendText("c", 1, { block: true });

    assert.strictEqual(composer.reply, "a\n\nc\n\nb");

    composer.clearState();
    composer.appendText("\nab");
    composer.appendText("c", 0, { block: true });

    assert.strictEqual(composer.reply, "c\n\nab");
  });

  test("prependText", function (assert) {
    const composer = createComposer.call(this);

    assert.blank(composer.reply, "the reply is blank by default");

    composer.prependText("hello");
    assert.strictEqual(composer.reply, "hello", "it prepends text to nothing");

    composer.prependText("world ");
    assert.strictEqual(
      composer.reply,
      "world hello",
      "it prepends text to existing text"
    );

    composer.prependText("before new line", { new_line: true });
    assert.strictEqual(
      composer.reply,
      "before new line\n\nworld hello",
      "it prepends text with new line to existing text"
    );
  });

  test("Title length for regular topics", function (assert) {
    this.siteSettings.min_topic_title_length = 5;
    this.siteSettings.max_topic_title_length = 10;
    const composer = createComposer.call(this);

    composer.set("title", "asdf");
    assert.false(composer.titleLengthValid, "short titles are not valid");

    composer.set("title", "this is a long title");
    assert.false(composer.titleLengthValid, "long titles are not valid");

    composer.set("title", "just right");
    assert.true(composer.titleLengthValid, "in the range is okay");
  });

  test("Title length for private messages", function (assert) {
    this.siteSettings.min_personal_message_title_length = 5;
    this.siteSettings.max_topic_title_length = 10;
    const composer = createComposer.call(this, { action: PRIVATE_MESSAGE });

    composer.set("title", "asdf");
    assert.false(composer.titleLengthValid, "short titles are not valid");

    composer.set("title", "this is a long title");
    assert.false(composer.titleLengthValid, "long titles are not valid");

    composer.set("title", "just right");
    assert.true(composer.titleLengthValid, "in the range is okay");
  });

  test("Post length for private messages with non human users", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const topic = store.createRecord("topic", { pm_with_non_human_user: true });
    const composer = createComposer.call(this, {
      topic,
    });

    assert.strictEqual(composer.minimumPostLength, 1);
  });

  test("editingFirstPost", function (assert) {
    const composer = createComposer.call(this);
    assert.false(composer.editingFirstPost, "false by default");

    const store = getOwner(this).lookup("service:store");
    const post = store.createRecord("post", { id: 123, post_number: 2 });
    composer.setProperties({ post, action: EDIT });
    assert.false(
      composer.editingFirstPost,
      "false when not editing the first post"
    );

    post.set("post_number", 1);
    assert.true(composer.editingFirstPost, "true when editing the first post");
  });

  test("clearState", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const composer = createComposer.call(this, {
      originalText: "asdf",
      reply: "asdf2",
      post: store.createRecord("post", { id: 1 }),
      title: "wat",
    });

    composer.clearState();

    assert.blank(composer.originalText);
    assert.blank(composer.reply);
    assert.blank(composer.post);
    assert.blank(composer.title);
  });

  test("initial category when uncategorized is allowed", function (assert) {
    this.siteSettings.allow_uncategorized_topics = true;
    const composer = openComposer.call(this, {
      action: CREATE_TOPIC,
      draftKey: "abcd",
      draftSequence: 1,
    });
    assert.strictEqual(composer.categoryId, null, "Uncategorized by default");
  });

  test("initial category when uncategorized is not allowed", function (assert) {
    this.siteSettings.allow_uncategorized_topics = false;
    const composer = openComposer.call(this, {
      action: CREATE_TOPIC,
      draftKey: "abcd",
      draftSequence: 1,
    });
    assert.strictEqual(
      composer.categoryId,
      null,
      "Uncategorized by default. Must choose a category."
    );
  });

  test("initial category when creating PM and there is a default composer category", function (assert) {
    this.siteSettings.default_composer_category = 2;
    const composer = openComposer.call(this, {
      action: PRIVATE_MESSAGE,
      draftKey: "abcd",
      draftSequence: 1,
    });
    assert.strictEqual(
      composer.categoryId,
      null,
      "it doesn't save the category"
    );
  });

  test("open with a quote", function (assert) {
    const quote =
      '[quote="neil, post:5, topic:413"]\nSimmer down you two.\n[/quote]';
    const newComposer = () => {
      return openComposer.call(this, {
        action: REPLY,
        draftKey: "abcd",
        draftSequence: 1,
        quote,
      });
    };

    assert.strictEqual(
      newComposer().originalText,
      quote,
      "originalText is the quote"
    );
    assert.false(
      newComposer().replyDirty,
      "replyDirty is initially false with a quote"
    );
  });

  test("Title length for static page topics as admin", function (assert) {
    this.siteSettings.min_topic_title_length = 5;
    this.siteSettings.max_topic_title_length = 10;
    const composer = createComposer.call(this);

    const store = getOwner(this).lookup("service:store");
    const post = store.createRecord("post", {
      id: 123,
      post_number: 2,
      static_doc: true,
    });
    composer.setProperties({ post, action: EDIT });

    composer.set("title", "asdf");
    assert.true(composer.titleLengthValid, "admins can use short titles");

    composer.set("title", "this is a long title");
    assert.true(composer.titleLengthValid, "admins can use long titles");

    composer.set("title", "just right");
    assert.true(composer.titleLengthValid, "in the range is okay");

    composer.set("title", "");
    assert.false(
      composer.titleLengthValid,
      "admins must set title to at least 1 character"
    );
  });

  test("title placeholder depends on what you're doing", function (assert) {
    this.siteSettings.topic_featured_link_enabled = false;
    let composer = createComposer.call(this, { action: CREATE_TOPIC });
    assert.strictEqual(
      composer.titlePlaceholder,
      "composer.title_placeholder",
      "placeholder for normal topic"
    );

    composer = createComposer.call(this, { action: PRIVATE_MESSAGE });
    assert.strictEqual(
      composer.titlePlaceholder,
      "composer.title_placeholder",
      "placeholder for private message"
    );

    this.siteSettings.topic_featured_link_enabled = true;

    composer = createComposer.call(this, { action: CREATE_TOPIC });
    assert.strictEqual(
      composer.titlePlaceholder,
      "composer.title_or_link_placeholder",
      "placeholder invites you to paste a link"
    );

    composer = createComposer.call(this, { action: PRIVATE_MESSAGE });
    assert.strictEqual(
      composer.titlePlaceholder,
      "composer.title_placeholder",
      "placeholder for private message with topic links enabled"
    );
  });

  test("allows featured link before choosing a category", function (assert) {
    this.siteSettings.topic_featured_link_enabled = true;
    this.siteSettings.allow_uncategorized_topics = false;
    const composer = createComposer.call(this, { action: CREATE_TOPIC });
    assert.strictEqual(
      composer.titlePlaceholder,
      "composer.title_or_link_placeholder",
      "placeholder invites you to paste a link"
    );
    assert.true(composer.canEditTopicFeaturedLink, "can paste link");
  });

  test("targetRecipientsArray contains types", function (assert) {
    const composer = createComposer.call(this, {
      targetRecipients: "test,codinghorror,staff,foo@bar.com",
    });
    assert.deepEqual(composer.targetRecipientsArray, [
      { name: "test", type: "user" },
      { name: "codinghorror", type: "user" },
      { name: "staff", type: "group" },
      { name: "foo@bar.com", type: "email" },
    ]);
  });

  test("can add meta_data", async function (assert) {
    let saved = false;
    pretender.post("/posts", function (request) {
      const data = parsePostData(request.requestBody);

      assert.strictEqual(data.meta_data.some_custom_field, "some_value");
      saved = true;

      return response(200, {
        success: true,
        action: "create_post",
        post: {
          id: 12345,
          topic_id: 280,
          topic_slug: "internationalization-localization",
        },
      });
    });
    const composer = createComposer.call(this, {});

    await composer.open({
      action: CREATE_TOPIC,
      title: "some topic title here",
      categoryId: 1,
      reply: "some reply here some reply here some reply here",
      draftKey: "abcd",
      draftSequence: 1,
    });

    assert.false(composer.loading);

    composer.metaData = { some_custom_field: "some_value" };
    await composer.save({});

    assert.true(saved);
  });
});
