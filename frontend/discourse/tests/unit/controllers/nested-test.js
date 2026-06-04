import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Unit | Controller | nested", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.appEvents = this.owner.lookup("service:app-events");
    this.controller = this.owner.lookup("controller:nested");
    this.store = this.owner.lookup("service:store");
  });

  hooks.afterEach(function () {
    this.controller.unsubscribe();
    this.controller.topic = null;
  });

  function buildTopic(store, id) {
    return store.createRecord("topic", {
      id,
      slug: `topic-${id}`,
    });
  }

  function buildPost(store, topic, id, postNumber) {
    const post = store.createRecord("post", {
      id,
      post_number: postNumber,
      topic,
    });
    post.topic = topic;
    return post;
  }

  test("post registry events are scoped to the current topic", function (assert) {
    const previousTopic = buildTopic(this.store, 509);
    const currentTopic = buildTopic(this.store, 724);
    const previousPost = buildPost(this.store, previousTopic, 1001, 2);
    const currentPost = buildPost(this.store, currentTopic, 2001, 2);

    this.controller.topic = currentTopic;
    this.controller.subscribe();

    this.appEvents.trigger("nested-replies:post-registered", previousPost);

    assert.false(
      this.controller.postRegistry.has(2),
      "ignores post registration from a previous topic"
    );

    this.appEvents.trigger("nested-replies:post-registered", currentPost);
    this.appEvents.trigger("nested-replies:post-unregistered", previousPost);

    assert.strictEqual(
      this.controller.postRegistry.get(2),
      currentPost,
      "does not unregister the current topic post for a stale same-number post"
    );

    this.appEvents.trigger("nested-replies:post-unregistered", currentPost);

    assert.false(
      this.controller.postRegistry.has(2),
      "unregisters the matching current topic post"
    );
  });
});
