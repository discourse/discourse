import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { fakeTime } from "discourse/tests/helpers/qunit-helpers";
import {
  formatMuteEnd,
  mutedUntilFromNow,
} from "discourse/plugins/chat/discourse/lib/chat-mute-durations";

module("Discourse Chat | Unit | Lib | chat-mute-durations", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.clock = fakeTime("2026-11-04T10:00:00", "UTC");
    this.currentUser = { user_option: { timezone: "UTC" } };
  });

  hooks.afterEach(function () {
    this.clock.restore();
  });

  test("mutedUntilFromNow", function (assert) {
    assert.strictEqual(mutedUntilFromNow(15), "2026-11-04T10:15:00.000Z");
  });

  test("formatMuteEnd shows only the time when the mute ends today", function (assert) {
    assert.strictEqual(
      formatMuteEnd("2026-11-04T18:00:00Z", this.currentUser),
      "6:00 PM"
    );
  });

  test("formatMuteEnd shows the date when the mute ends on another day", function (assert) {
    assert.strictEqual(
      formatMuteEnd("2026-11-05T09:30:00Z", this.currentUser),
      "Nov 5, 9:30 am"
    );
  });
});
