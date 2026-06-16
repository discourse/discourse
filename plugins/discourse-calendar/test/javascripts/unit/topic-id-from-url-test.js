import { module, test } from "qunit";
import { topicIdFromUrl } from "discourse/plugins/discourse-calendar/discourse/components/discourse-post-event/onebox-node-view";

module("Unit | discourse-post-event | topicIdFromUrl", function () {
  test("extracts the topic id for a topic / first-post link", function (assert) {
    assert.strictEqual(topicIdFromUrl("/t/some-slug/123"), 123);
    assert.strictEqual(
      topicIdFromUrl("https://example.com/t/some-slug/123"),
      123
    );
    assert.strictEqual(
      topicIdFromUrl("https://example.com/t/some-slug/123/1"),
      123,
      "treats an explicit first post as the topic"
    );
  });

  test("returns null for a link to a specific reply", function (assert) {
    assert.strictEqual(
      topicIdFromUrl("https://example.com/t/some-slug/123/4"),
      null
    );
  });

  test("returns null for non-topic urls", function (assert) {
    assert.strictEqual(topicIdFromUrl("https://example.com/c/cat/5"), null);
    assert.strictEqual(topicIdFromUrl("https://example.com"), null);
    assert.strictEqual(topicIdFromUrl(null), null);
    assert.strictEqual(topicIdFromUrl(undefined), null);
  });
});
