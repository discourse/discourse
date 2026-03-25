import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import nestedPostUrl from "discourse/lib/nested-post-url";

module("Unit | Lib | nested-post-url", function (hooks) {
  setupTest(hooks);

  test("builds a nested URL with topic slug, id and post number", function (assert) {
    const topic = { slug: "test-topic", id: 42 };

    assert.strictEqual(nestedPostUrl(topic, 5), "/n/test-topic/42/5");
  });

  test("always produces a URL without context param", function (assert) {
    const topic = { slug: "my-topic", id: 99 };

    assert.strictEqual(nestedPostUrl(topic, 7), "/n/my-topic/99/7");
  });
});
