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
