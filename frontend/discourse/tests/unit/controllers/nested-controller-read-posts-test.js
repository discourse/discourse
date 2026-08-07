import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Unit | Controller | nested - readPosts with postRegistry", function () {
  function makePost(postNumber, read = false) {
    let _read = read;
    return {
      post_number: postNumber,
      get read() {
        return _read;
      },
      set(key, value) {
        if (key === "read") {
          _read = value;
        }
      },
    };
  }

  function buildReadPosts(topicId, registry) {
    return function readPosts(calledTopicId, postNumbers) {
      if (topicId !== calledTopicId) {
        return;
      }
      for (const postNumber of postNumbers) {
        const post = registry.get(postNumber);
        if (post && !post.read) {
          post.set("read", true);
        }
      }
    };
  }

  test("marks a post as read", function (assert) {
    const registry = new Map();
    const post = makePost(2);
    registry.set(2, post);
    const readPosts = buildReadPosts(42, registry);

    readPosts(42, [2]);

    assert.true(post.read);
  });

  test("marks multiple posts as read in a single call", function (assert) {
    const registry = new Map();
    const posts = [
      makePost(2),
      makePost(3),
      makePost(4),
      makePost(5),
      makePost(6),
    ];
    for (const post of posts) {
      registry.set(post.post_number, post);
    }
    const readPosts = buildReadPosts(42, registry);

    readPosts(42, [2, 3, 4, 5, 6]);

    for (const post of posts) {
      assert.true(
        post.read,
        `post_number ${post.post_number} should be marked read`
      );
    }
  });

  test("does not mark already-read posts again", function (assert) {
    const registry = new Map();
    const post = makePost(2, true);
    let setCalled = false;
    const originalSet = post.set.bind(post);
    post.set = (key, value) => {
      setCalled = true;
      originalSet(key, value);
    };
    registry.set(2, post);
    const readPosts = buildReadPosts(42, registry);

    readPosts(42, [2]);

    assert.false(setCalled);
    assert.true(post.read);
  });

  test("ignores post numbers not in the registry", function (assert) {
    const registry = new Map();
    const post = makePost(2);
    registry.set(2, post);
    const readPosts = buildReadPosts(42, registry);

    readPosts(42, [2, 99]);

    assert.true(post.read);
    assert.strictEqual(registry.size, 1);
  });

  test("ignores calls for wrong topic id", function (assert) {
    const registry = new Map();
    const post = makePost(2);
    registry.set(2, post);
    const readPosts = buildReadPosts(42, registry);

    readPosts(999, [2]);

    assert.false(post.read);
  });
});

module("Unit | Controller | nested - bulk select delegation", function (hooks) {
  setupTest(hooks);

  hooks.afterEach(function () {
    document.getElementById("qunit-fixture").innerHTML = "";
  });

  function setTopicControllerModel(controller, postIds) {
    controller.setProperties({
      model: {
        postStream: {
          isMegaTopic: false,
          posts: postIds.map((id) => ({ id })),
          stream: postIds,
        },
      },
    });
    controller.selectedPostIds = [];
  }

  test("uses the topic controller selection state", function (assert) {
    const nestedController = this.owner.lookup("controller:nested");
    const topicController = this.owner.lookup("controller:topic");
    const post = { id: 123 };

    topicController.multiSelect = false;
    topicController.selectedPostIds = [];

    nestedController.toggleMultiSelect();

    assert.true(
      nestedController.multiSelect,
      "reflects multi-select state from the topic controller"
    );

    nestedController.togglePostSelection(post);

    assert.deepEqual(
      topicController.selectedPostIds,
      [post.id],
      "selects posts through the topic controller"
    );
    assert.true(
      nestedController.postSelected(post),
      "checks selection through the topic controller"
    );
  });

  test("selectBelow uses nested root view display order", function (assert) {
    const nestedController = this.owner.lookup("controller:nested");
    const topicController = this.owner.lookup("controller:topic");
    setTopicControllerModel(topicController, [1, 10, 30, 20, 40]);
    nestedController.contextMode = false;

    document.getElementById("qunit-fixture").innerHTML = `
      <div class="nested-view">
        <article data-post-id="1"></article>
        <article data-post-id="10"></article>
        <article data-post-id="30"></article>
        <article data-post-id="20"></article>
        <article data-post-id="40"></article>
      </div>
    `;

    nestedController.selectBelow({ id: 30 });

    assert.deepEqual(
      topicController.selectedPostIds,
      [30, 20, 40],
      "selects the clicked post and visible posts after it"
    );
  });

  test("selectBelow uses nested context view display order", function (assert) {
    const nestedController = this.owner.lookup("controller:nested");
    const topicController = this.owner.lookup("controller:topic");
    setTopicControllerModel(topicController, [1, 2, 3, 4, 5]);
    nestedController.contextMode = true;

    document.getElementById("qunit-fixture").innerHTML = `
      <div class="nested-view">
        <article data-post-id="5"></article>
      </div>
      <div class="nested-view nested-context-view">
        <article data-post-id="1"></article>
        <article data-post-id="2"></article>
        <article data-post-id="3"></article>
        <article data-post-id="4"></article>
      </div>
    `;

    nestedController.selectBelow({ id: 3 });

    assert.deepEqual(
      topicController.selectedPostIds,
      [3, 4],
      "selects below from the active context view"
    );
  });

  test("selectAll selects loaded nested post ids", function (assert) {
    const nestedController = this.owner.lookup("controller:nested");
    const topicController = this.owner.lookup("controller:topic");
    const posts = [{ id: 1 }, { id: 2 }, { id: 3 }];
    setTopicControllerModel(
      topicController,
      posts.map((post) => post.id)
    );
    nestedController.topic = {
      postStream: {
        posts,
      },
    };

    nestedController.selectAll();

    assert.deepEqual(
      topicController.selectedPostIds,
      [1, 2, 3],
      "selects the loaded nested posts"
    );
    assert.false(
      nestedController.canSelectAll,
      "does not offer select-all once loaded nested posts are selected"
    );
    assert.true(
      nestedController.canDeselectAll,
      "offers deselect when nested posts are selected"
    );
  });
});
