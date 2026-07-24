import { module, test } from "qunit";
import { eventHasLivestream } from "discourse/plugins/discourse-calendar/discourse/lib/livestream-utils";

module("Unit | Lib | livestream-utils", function () {
  test("eventHasLivestream requires both the flag and a URL", function (assert) {
    assert.true(
      eventHasLivestream({
        livestream: true,
        livestreamUrl: "https://us06web.zoom.us/j/123456789",
      }),
      "flagged with a URL"
    );

    assert.false(
      eventHasLivestream({ livestream: true, livestreamUrl: null }),
      "flagged without a URL"
    );
    assert.false(
      eventHasLivestream({ livestream: true, livestreamUrl: "" }),
      "flagged with a blank URL"
    );
    assert.false(
      eventHasLivestream({
        livestream: false,
        livestreamUrl: "https://us06web.zoom.us/j/123456789",
      }),
      "unflagged with a URL"
    );
  });

  test("eventHasLivestream handles a missing event", function (assert) {
    assert.false(eventHasLivestream(null));
    assert.false(eventHasLivestream(undefined));
  });
});
