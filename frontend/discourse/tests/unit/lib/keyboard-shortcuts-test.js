import Controller from "@ember/controller";
import { triggerKeyEvent } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import DiscourseURL from "discourse/lib/url";
import { logIn } from "discourse/tests/helpers/qunit-helpers";

module("Unit | Utility | keyboard-shortcuts", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    sinon.stub(DiscourseURL, "routeTo");
  });

  test("goBack calls history.back", function (assert) {
    let called = false;
    sinon.stub(history, "back").callsFake(function () {
      called = true;
    });

    const keyboardShortcuts = this.owner.lookup("service:keyboard-shortcuts");
    keyboardShortcuts.goBack();
    assert.true(called, "history.back is called");
  });

  test("nextSection calls _changeSection with 1", function (assert) {
    const keyboardShortcuts = this.owner.lookup("service:keyboard-shortcuts");
    let spy = sinon.spy(keyboardShortcuts, "_changeSection");

    keyboardShortcuts.nextSection();
    assert.true(spy.calledWith(1), "_changeSection is called with 1");
  });

  test("prevSection calls _changeSection with -1", function (assert) {
    const keyboardShortcuts = this.owner.lookup("service:keyboard-shortcuts");
    let spy = sinon.spy(keyboardShortcuts, "_changeSection");

    keyboardShortcuts.prevSection();
    assert.true(spy.calledWith(-1), "_changeSection is called with -1");
  });

  module("addShortcut context option", function () {
    test("fires new handler when CSS selector context matches", function (assert) {
      const ks = this.owner.lookup("service:keyboard-shortcuts");
      let handlerACalled = false;
      let handlerBCalled = false;

      ks.addShortcut("x", () => (handlerACalled = true), { anonymous: true });

      const el = document.createElement("div");
      el.classList.add("test-context-target");
      document.body.appendChild(el);

      try {
        ks.addShortcut("x", () => (handlerBCalled = true), {
          anonymous: true,
          context: ".test-context-target",
        });

        // Simulate keypress via ItsATrap
        ks.keyTrapper.trigger("x");

        assert.true(handlerBCalled, "new handler fires when context matches");
        assert.false(handlerACalled, "previous handler does not fire");
      } finally {
        el.remove();
      }
    });

    test("falls back to previous handler when context does not match", function (assert) {
      const ks = this.owner.lookup("service:keyboard-shortcuts");
      let handlerACalled = false;
      let handlerBCalled = false;

      ks.addShortcut("y", () => (handlerACalled = true), { anonymous: true });
      ks.addShortcut("y", () => (handlerBCalled = true), {
        anonymous: true,
        context: ".nonexistent-element",
      });

      ks.keyTrapper.trigger("y");

      assert.true(handlerACalled, "previous handler fires as fallback");
      assert.false(handlerBCalled, "new handler does not fire");
    });

    test("no error when no previous binding exists and context does not match", function (assert) {
      const ks = this.owner.lookup("service:keyboard-shortcuts");
      let called = false;

      ks.addShortcut("q w", () => (called = true), {
        anonymous: true,
        context: ".nonexistent-element",
      });

      ks.keyTrapper.trigger("q w");

      assert.false(called, "handler does not fire");
    });

    test("function context is evaluated", function (assert) {
      const ks = this.owner.lookup("service:keyboard-shortcuts");
      let contextActive = false;
      let handlerACalled = false;
      let handlerBCalled = false;

      ks.addShortcut("z", () => (handlerACalled = true), { anonymous: true });
      ks.addShortcut("z", () => (handlerBCalled = true), {
        anonymous: true,
        context: () => contextActive,
      });

      ks.keyTrapper.trigger("z");
      assert.true(handlerACalled, "fallback fires when function returns false");
      assert.false(handlerBCalled);

      handlerACalled = false;
      contextActive = true;
      ks.keyTrapper.trigger("z");
      assert.true(
        handlerBCalled,
        "new handler fires when function returns true"
      );
      assert.false(handlerACalled);
    });

    test("chained context bindings fall back correctly", function (assert) {
      const ks = this.owner.lookup("service:keyboard-shortcuts");
      const calls = [];

      ks.addShortcut("w", () => calls.push("original"), { anonymous: true });
      ks.addShortcut("w", () => calls.push("plugin-a"), {
        anonymous: true,
        context: ".plugin-a-active",
      });
      ks.addShortcut("w", () => calls.push("plugin-b"), {
        anonymous: true,
        context: ".plugin-b-active",
      });

      // Neither context matches — should fall through to original
      ks.keyTrapper.trigger("w");
      assert.deepEqual(calls, ["original"]);

      calls.length = 0;
      const elA = document.createElement("div");
      elA.classList.add("plugin-a-active");
      document.body.appendChild(elA);

      try {
        // plugin-b context doesn't match, falls to plugin-a which matches
        ks.keyTrapper.trigger("w");
        assert.deepEqual(calls, ["plugin-a"]);
      } finally {
        elA.remove();
      }

      calls.length = 0;
      const elB = document.createElement("div");
      elB.classList.add("plugin-b-active");
      document.body.appendChild(elB);

      try {
        // plugin-b context matches
        ks.keyTrapper.trigger("w");
        assert.deepEqual(calls, ["plugin-b"]);
      } finally {
        elB.remove();
      }
    });
  });

  module("nested view navigation", function (nestedHooks) {
    function appendPostControls(article) {
      const likeButton = document.createElement("button");
      likeButton.className = "toggle-like";
      article.appendChild(likeButton);

      const postDate = document.createElement("a");
      postDate.className = "post-date";
      postDate.href = "#";
      article.appendChild(postDate);
    }

    function makePostArticle(id, postId, postNumber, op = false) {
      const article = document.createElement("article");
      article.className = op
        ? "nested-view__op-article boxed"
        : "nested-post__article boxed";
      article.id = id;
      article.dataset.postId = postId;
      article.dataset.postNumber = postNumber;
      article.style.height = "20px";
      appendPostControls(article);
      return article;
    }

    function makePost(id, postId, postNumber) {
      const post = document.createElement("div");
      post.className = "nested-post";
      post.id = id;

      const main = document.createElement("div");
      main.className = "nested-post__main";
      main.appendChild(makePostArticle(`${id}-article`, postId, postNumber));
      post.appendChild(main);

      return post;
    }

    function buildNestedView() {
      const view = document.createElement("div");
      view.className = "nested-view";
      view.appendChild(makePostArticle("op", "100", "1", true));

      const roots = document.createElement("div");
      roots.className = "nested-view__roots";
      view.appendChild(roots);

      const r1 = makePost("r1", "101", "2");
      r1.querySelector(".nested-post__main").appendChild(
        makePost("r1-child", "102", "3")
      );
      roots.append(r1, makePost("r2", "103", "4"), makePost("r3", "104", "5"));

      document.body.appendChild(view);
      return view;
    }

    nestedHooks.afterEach(function () {
      document
        .querySelectorAll(".nested-view, .topic-post.selected")
        .forEach((el) => el.remove());
    });

    test("selectDown seeds the OP when nothing is selected", function (assert) {
      buildNestedView();
      const ks = this.owner.lookup("service:keyboard-shortcuts");

      ks.selectDown();

      assert.strictEqual(
        document.querySelector("[data-keyboard-selected]")?.id,
        "op"
      );
    });

    test("selectDown / selectUp walk the OP and every visible post in DOM order regardless of depth", function (assert) {
      buildNestedView();
      const ks = this.owner.lookup("service:keyboard-shortcuts");

      ks.selectDown(); // op
      ks.selectDown(); // r1
      ks.selectDown(); // r1-child
      assert.strictEqual(
        document.querySelector("[data-keyboard-selected]")?.id,
        "r1-child",
        "j descends into r1's child"
      );

      ks.selectDown(); // r2
      ks.selectDown(); // r3
      ks.selectDown(); // no-op past the last post
      assert.strictEqual(
        document.querySelector("[data-keyboard-selected]")?.id,
        "r3",
        "no wrap-around past the last post"
      );

      ks.selectUp(); // r2
      ks.selectUp(); // r1-child
      assert.strictEqual(
        document.querySelector("[data-keyboard-selected]")?.id,
        "r1-child"
      );

      ks.selectUp(); // r1
      ks.selectUp(); // op
      ks.selectUp(); // no-op before the first post
      assert.strictEqual(
        document.querySelector("[data-keyboard-selected]")?.id,
        "op",
        "no wrap-around past the OP"
      );
    });

    test("keyboard:move-selection fires with the selected post and the full post list", function (assert) {
      buildNestedView();
      const ks = this.owner.lookup("service:keyboard-shortcuts");
      const appEvents = this.owner.lookup("service:app-events");

      let payload;
      const handler = (data) => (payload = data);
      appEvents.on("keyboard:move-selection", handler);

      try {
        ks.selectDown(); // op
        assert.strictEqual(payload?.selectedArticle?.id, "op");
        assert.deepEqual(
          payload.articles.map((article) => article.id),
          ["op", "r1", "r1-child", "r2", "r3"],
          "payload mirrors the flat post-stream shape so Nested can detect boundary"
        );
      } finally {
        appEvents.off("keyboard:move-selection", handler);
      }
    });

    test("post actions target the selected OP and nested reply", function (assert) {
      const opPost = { id: 100, post_number: 1 };
      const nestedPost = { id: 101, post_number: 2 };
      let receivedPost;

      this.owner.register(
        "controller:topic",
        class extends Controller {
          model = { postStream: { posts: [opPost, nestedPost] } };
          actions = {
            replyToPost(post) {
              receivedPost = post;
            },
          };
        }
      );

      buildNestedView();
      const ks = this.owner.lookup("service:keyboard-shortcuts");

      ks.selectDown(); // op
      ks.sendToSelectedPost("replyToPost");
      assert.strictEqual(receivedPost, opPost);

      receivedPost = null;
      ks.selectDown(); // r1
      ks.sendToSelectedPost("replyToPost");
      assert.strictEqual(receivedPost, nestedPost);
    });

    test("like and share shortcuts click controls on selected nested articles", async function (assert) {
      const currentUser = logIn(this.owner);
      buildNestedView();
      const ks = this.owner.lookup("service:keyboard-shortcuts");
      ks.currentUser = currentUser;
      ks.bindKey("l");
      let liked = false;
      let shared = false;

      ks.selectDown(); // op
      ks.selectDown(); // r1

      const article = document.querySelector("#r1-article");
      article
        .querySelector(".toggle-like")
        .addEventListener("click", () => (liked = true));
      article.querySelector(".post-date").addEventListener("click", (event) => {
        event.preventDefault();
        shared = true;
      });

      await triggerKeyEvent(document.body, "keypress", "L");
      await triggerKeyEvent(document.body, "keypress", "S");

      assert.true(
        liked,
        "like shortcut clicks the selected nested article's like button"
      );
      assert.true(
        shared,
        "share shortcut clicks the selected nested article's date link"
      );
    });

    test("selectDown outside the nested view delegates to _moveSelection", function (assert) {
      const ks = this.owner.lookup("service:keyboard-shortcuts");
      const stub = sinon.stub(ks, "_moveSelection");
      try {
        ks.selectDown();
        assert.true(
          stub.calledWith({ direction: 1, scrollWithinPosts: true }),
          "falls through to flat-stream selection when .nested-view is absent"
        );
      } finally {
        stub.restore();
      }
    });
  });
});
