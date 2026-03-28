import { module, test } from "qunit";

module("Unit | Controller | nested – readPosts with postRegistry", function () {
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
