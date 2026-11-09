import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { restoreBaseUri, setupURL } from "discourse/lib/get-url";
import eventCalendarDetails from "discourse/plugins/discourse-events/discourse/lib/event-calendar-details";

module("Unit | Lib | event-calendar-details", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    setupURL(null, "https://forum.example", "");
  });

  hooks.afterEach(function () {
    restoreBaseUri();
  });

  test("preserves the description and appends the post URL", function (assert) {
    assert.strictEqual(
      eventCalendarDetails({
        description: "Bring your laptop\nQuestions welcome!",
        post: { url: "/t/workshop/123" },
        url: "https://external.example/meeting",
      }),
      "Bring your laptop\nQuestions welcome!\nhttps://forum.example/t/workshop/123",
      "the link returns to the topic rather than the external event website"
    );
  });

  test("includes the post URL with a missing description", function (assert) {
    assert.strictEqual(
      eventCalendarDetails({
        description: undefined,
        post: { url: "/t/workshop/123" },
      }),
      "https://forum.example/t/workshop/123",
      "blank descriptions leave just the absolute post URL"
    );
  });

  test("includes the post URL with a null description", function (assert) {
    assert.strictEqual(
      eventCalendarDetails({
        description: null,
        post: { url: "/t/workshop/123" },
      }),
      "https://forum.example/t/workshop/123",
      "blank descriptions leave just the absolute post URL"
    );
  });

  test("includes the post URL with a empty description", function (assert) {
    assert.strictEqual(
      eventCalendarDetails({
        description: "",
        post: { url: "/t/workshop/123" },
      }),
      "https://forum.example/t/workshop/123",
      "blank descriptions leave just the absolute post URL"
    );
  });

  test("includes the post URL with a whitespace-only description", function (assert) {
    assert.strictEqual(
      eventCalendarDetails({
        description: " \n ",
        post: { url: "/t/workshop/123" },
      }),
      "https://forum.example/t/workshop/123",
      "blank descriptions leave just the absolute post URL"
    );
  });

  test("handles missing post data", function (assert) {
    assert.strictEqual(
      eventCalendarDetails({ description: "Bring your laptop" }),
      "Bring your laptop",
      "the description is still available without a post"
    );
    assert.strictEqual(
      eventCalendarDetails({ post: {} }),
      "",
      "missing content does not produce an invalid URL"
    );
  });

  test("preserves the site subfolder exactly once", function (assert) {
    setupURL(null, "https://forum.example/community", "/community");

    assert.strictEqual(
      eventCalendarDetails({ post: { url: "/community/t/workshop/123" } }),
      "https://forum.example/community/t/workshop/123",
      "the post URL includes the configured subfolder"
    );
  });
});
