import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import {
  adoptAnonymousFlatRepliesPreference,
  switchTopicView,
  toggleFlatRepliesPreference,
} from "discourse/lib/nested-view-preference";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { logIn } from "discourse/tests/helpers/qunit-helpers";

module("Unit | Lib | nested-view-preference", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.keyValueStore = this.owner.lookup("service:key-value-store");
  });

  hooks.afterEach(function () {
    this.keyValueStore.remove("prefer_flat_replies");
  });

  test("copies the anonymous flat preference to the account", async function (assert) {
    const user = logIn(this.owner);
    let savedValue;
    pretender.put("/u/eviltrout.json", (request) => {
      savedValue = new URLSearchParams(request.requestBody).get(
        "prefer_flat_replies"
      );
      return response(200, { user: {} });
    });
    this.keyValueStore.set({ key: "prefer_flat_replies", value: "true" });

    await adoptAnonymousFlatRepliesPreference(user, this.keyValueStore);

    assert.strictEqual(savedValue, "true");
    assert.true(user.user_option.prefer_flat_replies);
    assert.strictEqual(
      this.keyValueStore.get("prefer_flat_replies"),
      undefined
    );
  });

  test("does nothing without an anonymous preference", async function (assert) {
    const user = logIn(this.owner);
    let requests = 0;
    pretender.put("/u/eviltrout.json", () => {
      requests++;
      return response(200, { user: {} });
    });

    await adoptAnonymousFlatRepliesPreference(user, this.keyValueStore);

    assert.strictEqual(requests, 0);
    assert.false(!!user.user_option.prefer_flat_replies);
  });

  module("visible post when switching", function (switchHooks) {
    switchHooks.beforeEach(function () {
      this.container = document.createElement("div");
      this.container.className = "nested-view";
      document.querySelector("#qunit-fixture").appendChild(this.container);
      this.headerOffset =
        document.documentElement.style.getPropertyValue("--header-offset");
      document.documentElement.style.setProperty("--header-offset", "60px");
      this.topic = {
        id: 123,
        slug: "example",
        rendersNested: true,
        currentPost: 3,
      };
      this.router = {
        currentRoute: {
          name: "topic.fromParamsNear",
          params: { nearPost: "3" },
        },
        replaceWith: (path) => (this.path = path),
        refresh: () => (this.refreshed = true),
      };
      this.addPost = (number, top, bottom, width = 600) => {
        const element = document.createElement("article");
        element.className = "topic-post";
        element.dataset.postNumber = number;
        element.getBoundingClientRect = () => ({
          top,
          bottom,
          width,
          height: bottom - top,
        });
        this.container.appendChild(element);
        return element;
      };
      this.switch = () =>
        switchTopicView(this.router, this.topic, () => {
          this.topic.rendersNested = !this.topic.rendersNested;
        });
    });

    switchHooks.afterEach(function () {
      this.container.remove();
      document.documentElement.style.setProperty(
        "--header-offset",
        this.headerOffset
      );
    });

    test("nested context uses the visible reply instead of the URL", async function (assert) {
      this.addPost(3, -200, 50);
      this.addPost(8, 70, 300);
      await this.switch();
      assert.strictEqual(this.path, "/t/example/123/8");
    });

    test("nested root preserves a long post crossing the viewport top", async function (assert) {
      this.router.currentRoute = { name: "topic.fromParams" };
      this.addPost(8, -1000, 200);
      this.addPost(9, 210, 400);
      await this.switch();
      assert.strictEqual(this.path, "/t/example/123/8");
    });

    test("ignores hidden posts and posts covered by the sticky controls", async function (assert) {
      const controls = document.createElement("div");
      controls.className = "nested-view__controls";
      controls.getBoundingClientRect = () => ({ top: 60, bottom: 110 });
      this.container.appendChild(controls);
      this.addPost(3, 60, 100);
      this.addPost(4, 110, 200, 0);
      this.addPost(8, 120, 300);
      await this.switch();
      assert.strictEqual(this.path, "/t/example/123/8");
    });

    test("flat view uses the visible post instead of stale tracking state", async function (assert) {
      this.topic.rendersNested = false;
      this.addPost(8, 70, 300);
      await this.switch();
      assert.strictEqual(this.path, "/t/example/123/8");
    });

    test("refreshes when the visible post already matches the route", async function (assert) {
      this.addPost(3, 70, 300);
      await this.switch();
      assert.true(this.refreshed);
      assert.strictEqual(this.path, undefined);
    });

    test("falls back to the route when no post is visible", async function (assert) {
      this.addPost(8, -200, 0);
      await this.switch();
      assert.true(this.refreshed);
    });

    test("a visible OP takes precedence over the context URL", async function (assert) {
      this.addPost(1, 70, 300);
      await this.switch();
      assert.strictEqual(this.path, "/t/example/123");
    });

    test("captures the visible post before saving the preference", async function (assert) {
      const user = logIn(this.owner);
      const post = this.addPost(8, 70, 300);
      pretender.put("/u/eviltrout.json", () => {
        post.getBoundingClientRect = () => ({
          top: -300,
          bottom: -100,
          width: 600,
          height: 200,
        });
        this.addPost(9, 70, 300);
        return response(200, { user: {} });
      });
      await toggleFlatRepliesPreference({
        currentUser: user,
        keyValueStore: this.keyValueStore,
        router: this.router,
        topic: this.topic,
      });
      assert.strictEqual(this.path, "/t/example/123/8");
    });

    test("a superseded transition is not reported as an error", async function (assert) {
      const aborted = Promise.reject(
        Object.assign(new Error("TransitionAborted"), {
          name: "TransitionAborted",
        })
      );
      aborted.catch(() => {});
      this.router.replaceWith = (path) => {
        this.path = path;
        return aborted;
      };
      this.addPost(8, 70, 300);
      pretender.put("/u/eviltrout.json", () => response(200, { user: {} }));
      const alert = sinon.stub(this.owner.lookup("service:dialog"), "alert");

      await toggleFlatRepliesPreference({
        currentUser: logIn(this.owner),
        keyValueStore: this.keyValueStore,
        router: this.router,
        topic: this.topic,
      });

      assert.strictEqual(this.path, "/t/example/123/8");
      assert.false(alert.called);
    });
  });
});
