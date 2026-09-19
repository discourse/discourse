import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import processNode from "discourse/lib/process-node";

module("Unit | Lib | process-node", function (hooks) {
  setupTest(hooks);

  function getStore(context) {
    return context.owner.lookup("service:store");
  }

  test("creates a post record from node data", function (assert) {
    const store = getStore(this);
    const topic = { id: 42, slug: "test" };
    const nodeData = {
      id: 100,
      post_number: 2,
      cooked: "<p>Hello</p>",
    };

    const result = processNode(store, topic, nodeData);

    assert.strictEqual(result.post.id, 100);
    assert.strictEqual(result.post.post_number, 2);
    assert.strictEqual(result.post.topic, topic);
  });

  test("stores post records in the topic post stream when available", function (assert) {
    const store = getStore(this);
    const storedPosts = [];
    const topic = {
      id: 42,
      slug: "test",
      postStream: {
        posts: [],
        stream: [],
        storePost(post) {
          storedPosts.push(post);
          return post;
        },
      },
    };
    const nodeData = { id: 100, post_number: 2 };

    const result = processNode(store, topic, nodeData);

    assert.strictEqual(storedPosts.length, 1);
    assert.strictEqual(storedPosts[0], result.post);
    assert.deepEqual(topic.postStream.posts, [result.post]);
    assert.deepEqual(topic.postStream.stream, [result.post.id]);
    assert.strictEqual(result.post.topic, topic);
  });

  test("does not duplicate existing post stream records", function (assert) {
    const store = getStore(this);
    const existingPost = store.createRecord("post", {
      id: 100,
      post_number: 2,
    });
    const topic = {
      id: 42,
      slug: "test",
      postStream: {
        posts: [existingPost],
        stream: [existingPost.id],
        storePost() {
          return existingPost;
        },
      },
    };
    const nodeData = { id: 100, post_number: 2 };

    const result = processNode(store, topic, nodeData);

    assert.strictEqual(result.post, existingPost);
    assert.deepEqual(topic.postStream.posts, [existingPost]);
    assert.deepEqual(topic.postStream.stream, [existingPost.id]);
  });

  test("returns empty children when node has no children", function (assert) {
    const store = getStore(this);
    const topic = { id: 42, slug: "test" };
    const nodeData = { id: 100, post_number: 2 };

    const result = processNode(store, topic, nodeData);

    assert.deepEqual(result.children, []);
  });

  test("returns empty children when children array is empty", function (assert) {
    const store = getStore(this);
    const topic = { id: 42, slug: "test" };
    const nodeData = { id: 100, post_number: 2, children: [] };

    const result = processNode(store, topic, nodeData);

    assert.deepEqual(result.children, []);
  });

  test("recursively processes children", function (assert) {
    const store = getStore(this);
    const topic = { id: 42, slug: "test" };
    const nodeData = {
      id: 100,
      post_number: 2,
      children: [
        {
          id: 101,
          post_number: 3,
          children: [{ id: 102, post_number: 4 }],
        },
        { id: 103, post_number: 5 },
      ],
    };

    const result = processNode(store, topic, nodeData);

    assert.strictEqual(result.children.length, 2);
    assert.strictEqual(result.children[0].post.id, 101);
    assert.strictEqual(result.children[0].post.topic, topic);
    assert.strictEqual(result.children[0].children.length, 1);
    assert.strictEqual(result.children[0].children[0].post.id, 102);
    assert.strictEqual(result.children[0].children[0].post.topic, topic);
    assert.strictEqual(result.children[1].post.id, 103);
    assert.strictEqual(result.children[1].children.length, 0);
  });
});
