import { module, test } from "qunit";
import { topicIdFromUrl } from "discourse/plugins/discourse-calendar/discourse/components/discourse-post-event/onebox-node-view";

const ORIGIN = window.location.origin;

module("Unit | discourse-post-event | topicIdFromUrl", function () {
  test("extracts the topic id for a topic / first-post link", function (assert) {
    assert.strictEqual(topicIdFromUrl("/t/some-slug/123"), 123);
    assert.strictEqual(topicIdFromUrl(`${ORIGIN}/t/some-slug/123`), 123);
    assert.strictEqual(
      topicIdFromUrl(`${ORIGIN}/t/some-slug/123/1`),
      123,
      "treats an explicit first post as the topic"
    );
  });

  test("returns null for a link to a specific reply", function (assert) {
    assert.strictEqual(topicIdFromUrl(`${ORIGIN}/t/some-slug/123/4`), null);
  });

  test("returns null for an off-site Discourse url", function (assert) {
    assert.strictEqual(
      topicIdFromUrl("https://meta.discourse.org/t/foo/123"),
      null,
      "does not treat another Discourse site's topic as a local topic"
    );
  });

  test("returns null for slugless urls instead of misreading the post number", function (assert) {
    assert.strictEqual(topicIdFromUrl(`${ORIGIN}/t/123/2`), null);
    assert.strictEqual(topicIdFromUrl(`${ORIGIN}/t/123`), null);
  });

  test("returns null for non-topic urls", function (assert) {
    assert.strictEqual(topicIdFromUrl(`${ORIGIN}/c/cat/5`), null);
    assert.strictEqual(topicIdFromUrl(ORIGIN), null);
    assert.strictEqual(topicIdFromUrl(null), null);
    assert.strictEqual(topicIdFromUrl(undefined), null);
  });
});
