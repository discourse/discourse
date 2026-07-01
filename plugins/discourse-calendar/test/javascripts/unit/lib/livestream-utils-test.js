import { module, test } from "qunit";
import {
  isSupportedZoomJoinUrl,
  parseZoomJoinUrl,
} from "../../discourse/lib/livestream-utils";

module("Unit | discourse-calendar | lib | livestream-utils", function () {
  test("parses supported Zoom join URLs", function (assert) {
    assert.deepEqual(
      parseZoomJoinUrl("https://us06web.zoom.us/j/123456789?pwd=secret"),
      {
        meetingNumber: "123456789",
        password: "secret",
        url: "https://us06web.zoom.us/j/123456789?pwd=secret",
      }
    );
  });

  test("rejects unsupported URLs", function (assert) {
    assert.false(isSupportedZoomJoinUrl("https://example.com/watch/123"));
    assert.false(isSupportedZoomJoinUrl("not-a-url"));
  });
});
