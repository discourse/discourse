import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import zoomFrameUrl from "discourse/plugins/discourse-events/discourse/lib/zoom-frame-url";

module("Unit | Lib | zoom-frame-url", function (hooks) {
  setupTest(hooks);

  test("addresses the frame that serves the meeting", function (assert) {
    const url = new URL(zoomFrameUrl({ topicId: 7 }), "http://localhost");

    assert.strictEqual(
      url.pathname,
      "/discourse-calendar/livestream/zoom/frame"
    );
    assert.strictEqual(url.searchParams.get("topic_id"), "7");
  });

  // The frame joins the meeting as it loads, so a retry has to be a URL the
  // browser treats as a new one.
  test("carries the attempt, so a retry reloads the frame", function (assert) {
    const first = zoomFrameUrl({ topicId: 7, attempt: 0 });
    const second = zoomFrameUrl({ topicId: 7, attempt: 1 });

    assert.notStrictEqual(first, second);
  });
});
