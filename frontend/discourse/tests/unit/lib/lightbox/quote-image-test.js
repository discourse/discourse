import Controller from "@ember/controller";
import Service from "@ember/service";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import quoteImage, { canQuoteImage } from "discourse/lib/lightbox/quote-image";
import Draft from "discourse/models/draft";

class ComposerStub extends Service {
  model = { viewOpen: false };
  openCalls = [];

  async open(args) {
    this.openCalls.push(args);
  }
}

class StoreStub extends Service {
  constructor() {
    super(...arguments);
    this.posts = new Map();
    this.topics = new Map();
  }

  peekRecord(type, id) {
    const key = id?.toString();

    if (type === "post") {
      return this.posts.get(key);
    }

    if (type === "topic") {
      return this.topics.get(key);
    }

    return null;
  }

  async find(type, id) {
    return this.peekRecord(type, id);
  }
}

class AppEventsStub extends Service {
  events = [];

  trigger(...args) {
    this.events.push(args);
  }
}

module("Unit | Lib | lightbox | quote image", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.owner.unregister("service:composer");
    this.owner.unregister("service:store");
    this.owner.unregister("service:app-events");

    this.owner.register("service:composer", ComposerStub);
    this.owner.register("service:store", StoreStub);
    this.owner.register("service:app-events", AppEventsStub);
    this.owner.register("controller:topic", class extends Controller {});

    this.composer = this.owner.lookup("service:composer");
    this.store = this.owner.lookup("service:store");
    this.appEvents = this.owner.lookup("service:app-events");
    this.topicController = this.owner.lookup("controller:topic");

    this.topic = { id: 100, draft_key: "topic_100", draft_sequence: 5 };
    this.post = {
      id: 321,
      post_number: 2,
      username: "alice",
      name: "Alice",
      topic_id: this.topic.id,
      topicId: this.topic.id,
      topic: this.topic,
    };

    this.store.posts.set(this.post.id.toString(), this.post);
    this.store.topics.set(this.topic.id.toString(), this.topic);

    this.draftGetStub = sinon.stub(Draft, "get").resolves({});
  });

  hooks.afterEach(function () {
    document.querySelectorAll(".topic-post").forEach((el) => el.remove());
    this.draftGetStub.restore();
  });

  function buildLightbox(context, overrides = {}) {
    const topicPost = document.createElement("div");
    topicPost.classList.add("topic-post");
    topicPost.dataset.postNumber = overrides.postNumber || "2";

    const article = document.createElement("article");
    article.dataset.postId = overrides.postId || "321";
    article.dataset.topicId = overrides.topicId || "100";
    topicPost.appendChild(article);

    const link = document.createElement("a");
    const targetWidth = overrides.targetWidth || "640";
    const targetHeight = overrides.targetHeight || "480";
    const href = overrides.href || "/uploads/example.png";
    const origSrc =
      overrides.origSrc !== undefined
        ? overrides.origSrc
        : "upload://secure.png";

    link.classList.add("lightbox");
    link.dataset.targetWidth = targetWidth;
    link.dataset.targetHeight = targetHeight;
    link.setAttribute("href", href);
    article.appendChild(link);

    const img = document.createElement("img");
    if (overrides.origSrc !== undefined) {
      img.setAttribute("data-orig-src", overrides.origSrc);
    } else {
      img.setAttribute("data-orig-src", "upload://secure.png");
    }
    if (overrides.base62SHA1) {
      img.setAttribute("data-base62-sha1", overrides.base62SHA1);
    }
    img.setAttribute("alt", overrides.alt || "diagram");
    img.setAttribute("width", overrides.width || "640");
    img.setAttribute("height", overrides.height || "480");
    link.appendChild(img);

    document.body.appendChild(topicPost);

    const slideData = {
      element: link,
      src: href,
      origSrc,
      title: overrides.alt || "diagram",
      targetWidth,
      targetHeight,
      base62SHA1: overrides.base62SHA1,
      post: overrides.post || context.post,
    };

    return { element: link, slideData };
  }

  test("returns false when the element is outside a post", async function (assert) {
    const element = document.createElement("a");
    element.classList.add("lightbox");
    element.appendChild(document.createElement("img"));

    const result = await quoteImage(element, {});

    assert.false(result, "quoteImage short-circuits without post context");
    assert.strictEqual(
      this.composer.openCalls.length,
      0,
      "composer.open is not called"
    );
    assert.strictEqual(
      this.appEvents.events.length,
      0,
      "no composer insert event is fired"
    );
  });

  test("canQuoteImage only returns true when context and metadata exist", function (assert) {
    const invalid = document.createElement("a");
    assert.false(canQuoteImage(invalid, {}));

    const { element, slideData } = buildLightbox(this);
    assert.true(canQuoteImage(element, slideData));
  });

  test("builds markdown using data-orig-src and dimensions when composer is closed", async function (assert) {
    const { element, slideData } = buildLightbox(this, {
      origSrc: "upload://original.png",
      targetWidth: "800",
      targetHeight: "600",
    });

    const result = await quoteImage(element, slideData);

    assert.true(result, "quoteImage succeeds");
    assert.strictEqual(this.composer.openCalls.length, 1);
    const quote = this.composer.openCalls[0].quote;
    assert.true(
      quote.includes("![diagram|800x600](upload://original.png)"),
      "markdown prefers data-orig-src and size"
    );
    assert.true(quote.includes("post:2"), "quote metadata references the post");
  });

  test("inserts into an open composer via app events", async function (assert) {
    this.composer.model.viewOpen = true;
    const { element, slideData } = buildLightbox(this);

    const result = await quoteImage(element, slideData);

    assert.true(result);
    assert.strictEqual(this.composer.openCalls.length, 0);
    assert.strictEqual(this.appEvents.events.length, 1, "event triggered once");
    assert.true(
      this.appEvents.events[0][1].includes("![diagram|640x480]"),
      "quoted markdown is inserted"
    );
  });

  test("falls back to the rendered href when no data-orig-src exists", async function (assert) {
    const { element, slideData } = buildLightbox(this, { origSrc: "" });

    const result = await quoteImage(element, slideData);

    assert.true(result);
    const quote = this.composer.openCalls[0].quote;
    assert.true(
      quote.includes("](/uploads/example.png)"),
      "fallback uses the link href"
    );
  });

  test("uses short upload:// URL when data-base62-sha1 is present", async function (assert) {
    const { element, slideData } = buildLightbox(this, {
      base62SHA1: "a4bcwvmLAy8cGHKPUrK4G3AUbt9",
      href: "//localhost:4200/uploads/default/original/1X/468eb8aa1f0126f1ce7e7ea7a2f64f25da0b58db.png",
      origSrc: "",
    });

    const result = await quoteImage(element, slideData);

    assert.true(result);
    const quote = this.composer.openCalls[0].quote;
    assert.true(
      quote.includes(
        "![diagram|640x480](upload://a4bcwvmLAy8cGHKPUrK4G3AUbt9)"
      ),
      "uses short upload:// URL format with base62-sha1"
    );
  });

  test("expands minimized composer and appends quote when viewDraft is true", async function (assert) {
    const existingReply = "Existing draft content";
    this.composer.model = {
      viewOpen: false,
      viewDraft: true,
      reply: existingReply,
    };

    let openIfDraftCalled = false;
    this.composer.openIfDraft = () => {
      openIfDraftCalled = true;
    };

    const { element, slideData } = buildLightbox(this);

    const result = await quoteImage(element, slideData);

    assert.true(result);
    assert.strictEqual(
      this.composer.openCalls.length,
      0,
      "composer.open not called"
    );
    assert.true(openIfDraftCalled, "openIfDraft was called to expand composer");
    assert.true(
      this.composer.model.reply.includes(existingReply),
      "existing draft content preserved"
    );
    assert.true(
      this.composer.model.reply.includes("![diagram|640x480]"),
      "quote appended to existing content"
    );
  });

  test("loads existing draft and appends quote when draft exists", async function (assert) {
    const existingDraftContent = "This is my existing draft";
    this.draftGetStub.resolves({
      draft: JSON.stringify({ reply: existingDraftContent }),
      draft_sequence: 10,
    });

    const { element, slideData } = buildLightbox(this);

    const result = await quoteImage(element, slideData);

    assert.true(result);
    assert.strictEqual(this.composer.openCalls.length, 1);

    const composerOpts = this.composer.openCalls[0];
    assert.true(
      composerOpts.reply.includes(existingDraftContent),
      "existing draft content included"
    );
    assert.true(
      composerOpts.reply.includes("![diagram|640x480]"),
      "quote appended to draft"
    );
    assert.strictEqual(
      composerOpts.draftSequence,
      10,
      "draft sequence from server used"
    );
    assert.strictEqual(
      composerOpts.quote,
      undefined,
      "quote option not used when draft exists"
    );
  });
});
