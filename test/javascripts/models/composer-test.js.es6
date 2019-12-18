import EmberObject from "@ember/object";
import { currentUser } from "helpers/qunit-helpers";
import AppEvents from "discourse/services/app-events";
import Composer from "discourse/models/composer";
import Post from "discourse/models/post";
import createStore from "helpers/create-store";

QUnit.module("model:composer");

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

QUnit.test("replyLength", assert => {
  const replyLength = function(val, expectedLength) {
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
});

QUnit.test("missingReplyCharacters", assert => {
  Discourse.SiteSettings.min_first_post_length = 40;
  const missingReplyCharacters = function(
    val,
    isPM,
    isFirstPost,
    expected,
    message
  ) {
    const composer = createComposer({
      reply: val,
      creatingPrivateMessage: isPM,
      creatingTopic: isFirstPost
    });
    assert.equal(composer.get("missingReplyCharacters"), expected, message);
  };

  missingReplyCharacters(
    "hi",
    false,
    false,
    Discourse.SiteSettings.min_post_length - 2,
    "too short public post"
  );
  missingReplyCharacters(
    "hi",
    false,
    true,
    Discourse.SiteSettings.min_first_post_length - 2,
    "too short first post"
  );
  missingReplyCharacters(
    "hi",
    true,
    false,
    Discourse.SiteSettings.min_personal_message_post_length - 2,
    "too short private message"
  );

  const link = "http://imgur.com/gallery/grxX8";
  const composer = createComposer({
    canEditTopicFeaturedLink: true,
    title: link,
    featuredLink: link,
    reply: link
  });

  assert.equal(
    composer.get("missingReplyCharacters"),
    0,
    "don't require any post content"
  );
});

QUnit.test("missingTitleCharacters", assert => {
  const missingTitleCharacters = function(val, isPM, expected, message) {
    const composer = createComposer({
      title: val,
      creatingPrivateMessage: isPM
    });
    assert.equal(composer.get("missingTitleCharacters"), expected, message);
  };

  missingTitleCharacters(
    "hi",
    false,
    Discourse.SiteSettings.min_topic_title_length - 2,
    "too short post title"
  );
  missingTitleCharacters(
    "z",
    true,
    Discourse.SiteSettings.min_personal_message_title_length - 1,
    "too short pm title"
  );
});

QUnit.test("replyDirty", assert => {
  const composer = createComposer();
  assert.ok(!composer.get("replyDirty"), "by default it's false");

  composer.setProperties({
    originalText: "hello",
    reply: "hello"
  });

  assert.ok(
    !composer.get("replyDirty"),
    "it's false when the originalText is the same as the reply"
  );
  composer.set("reply", "hello world");
  assert.ok(composer.get("replyDirty"), "it's true when the reply changes");
});

QUnit.test("appendText", assert => {
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

QUnit.test("prependText", assert => {
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

QUnit.test("Title length for regular topics", assert => {
  Discourse.SiteSettings.min_topic_title_length = 5;
  Discourse.SiteSettings.max_topic_title_length = 10;
  const composer = createComposer();

  composer.set("title", "asdf");
  assert.ok(!composer.get("titleLengthValid"), "short titles are not valid");

  composer.set("title", "this is a long title");
  assert.ok(!composer.get("titleLengthValid"), "long titles are not valid");

  composer.set("title", "just right");
  assert.ok(composer.get("titleLengthValid"), "in the range is okay");
});

QUnit.test("Title length for private messages", assert => {
  Discourse.SiteSettings.min_personal_message_title_length = 5;
  Discourse.SiteSettings.max_topic_title_length = 10;
  const composer = createComposer({ action: Composer.PRIVATE_MESSAGE });

  composer.set("title", "asdf");
  assert.ok(!composer.get("titleLengthValid"), "short titles are not valid");

  composer.set("title", "this is a long title");
  assert.ok(!composer.get("titleLengthValid"), "long titles are not valid");

  composer.set("title", "just right");
  assert.ok(composer.get("titleLengthValid"), "in the range is okay");
});

QUnit.test("Title length for private messages", assert => {
  Discourse.SiteSettings.min_personal_message_title_length = 5;
  Discourse.SiteSettings.max_topic_title_length = 10;
  const composer = createComposer({ action: Composer.PRIVATE_MESSAGE });

  composer.set("title", "asdf");
  assert.ok(!composer.get("titleLengthValid"), "short titles are not valid");

  composer.set("title", "this is a long title");
  assert.ok(!composer.get("titleLengthValid"), "long titles are not valid");

  composer.set("title", "just right");
  assert.ok(composer.get("titleLengthValid"), "in the range is okay");
});

QUnit.test("Post length for private messages with non human users", assert => {
  const composer = createComposer({
    topic: EmberObject.create({ pm_with_non_human_user: true })
  });

  assert.equal(composer.get("minimumPostLength"), 1);
});

QUnit.test("editingFirstPost", assert => {
  const composer = createComposer();
  assert.ok(!composer.get("editingFirstPost"), "it's false by default");

  const post = Post.create({ id: 123, post_number: 2 });
  composer.setProperties({ post: post, action: Composer.EDIT });
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

QUnit.test("clearState", assert => {
  const composer = createComposer({
    originalText: "asdf",
    reply: "asdf2",
    post: Post.create({ id: 1 }),
    title: "wat"
  });

  composer.clearState();

  assert.blank(composer.get("originalText"));
  assert.blank(composer.get("reply"));
  assert.blank(composer.get("post"));
  assert.blank(composer.get("title"));
});

QUnit.test("initial category when uncategorized is allowed", assert => {
  Discourse.SiteSettings.allow_uncategorized_topics = true;
  const composer = openComposer({
    action: "createTopic",
    draftKey: "asfd",
    draftSequence: 1
  });
  assert.ok(!composer.get("categoryId"), "Uncategorized by default");
});

QUnit.test("initial category when uncategorized is not allowed", assert => {
  Discourse.SiteSettings.allow_uncategorized_topics = false;
  const composer = openComposer({
    action: "createTopic",
    draftKey: "asfd",
    draftSequence: 1
  });
  assert.ok(
    !composer.get("categoryId"),
    "Uncategorized by default. Must choose a category."
  );
});

QUnit.test("open with a quote", assert => {
  const quote =
    '[quote="neil, post:5, topic:413"]\nSimmer down you two.\n[/quote]';
  const newComposer = function() {
    return openComposer({
      action: Composer.REPLY,
      draftKey: "asfd",
      draftSequence: 1,
      quote: quote
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
    "replyDirty is initally false with a quote"
  );
});

QUnit.test("Title length for static page topics as admin", assert => {
  Discourse.SiteSettings.min_topic_title_length = 5;
  Discourse.SiteSettings.max_topic_title_length = 10;
  const composer = createComposer();

  const post = Post.create({
    id: 123,
    post_number: 2,
    static_doc: true
  });
  composer.setProperties({ post: post, action: Composer.EDIT });

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

QUnit.test("title placeholder depends on what you're doing", assert => {
  let composer = createComposer({ action: Composer.CREATE_TOPIC });
  assert.equal(
    composer.get("titlePlaceholder"),
    "composer.title_placeholder",
    "placeholder for normal topic"
  );

  composer = createComposer({ action: Composer.PRIVATE_MESSAGE });
  assert.equal(
    composer.get("titlePlaceholder"),
    "composer.title_placeholder",
    "placeholder for private message"
  );

  Discourse.SiteSettings.topic_featured_link_enabled = true;

  composer = createComposer({ action: Composer.CREATE_TOPIC });
  assert.equal(
    composer.get("titlePlaceholder"),
    "composer.title_or_link_placeholder",
    "placeholder invites you to paste a link"
  );

  composer = createComposer({ action: Composer.PRIVATE_MESSAGE });
  assert.equal(
    composer.get("titlePlaceholder"),
    "composer.title_placeholder",
    "placeholder for private message with topic links enabled"
  );
});

QUnit.test("allows featured link before choosing a category", assert => {
  Discourse.SiteSettings.topic_featured_link_enabled = true;
  Discourse.SiteSettings.allow_uncategorized_topics = false;
  let composer = createComposer({ action: Composer.CREATE_TOPIC });
  assert.equal(
    composer.get("titlePlaceholder"),
    "composer.title_or_link_placeholder",
    "placeholder invites you to paste a link"
  );
  assert.ok(composer.get("canEditTopicFeaturedLink"), "can paste link");
});

QUnit.test("targetRecipientsArray contains types", assert => {
  let composer = createComposer({
    targetRecipients: "test,codinghorror,staff,foo@bar.com"
  });
  assert.ok(composer.targetRecipientsArray, [
    { type: "group", name: "test" },
    { type: "user", name: "codinghorror" },
    { type: "group", name: "staff" },
    { type: "email", name: "foo@bar.com" }
  ]);
});
