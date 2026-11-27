import { module, test } from "qunit";
import { i18n } from "discourse-i18n";
import {
  recurrenceContext,
  recurrenceRef,
} from "discourse/plugins/discourse-events/discourse/lib/event-recurrence";
import DiscoursePostEventEvent from "discourse/plugins/discourse-events/discourse/models/discourse-post-event-event";

module("Unit | Lib | event-recurrence", function () {
  test("uses the inherited anchor for a successor's recurrence label", function (assert) {
    const event = DiscoursePostEventEvent.create({
      starts_at: "2027-04-26T12:00:00Z",
      recurrence_anchor_starts_at: "2027-03-29T12:00:00Z",
      timezone: "UTC",
      recurrence: "every_month",
    });

    assert.strictEqual(event.startsAt, "2027-04-26T12:00:00Z");

    const ref = recurrenceRef(event);
    const context = recurrenceContext(ref);

    assert.strictEqual(ref.format("YYYY-MM-DD"), "2027-03-29");
    assert.strictEqual(context.weekday, "Monday");
    assert.strictEqual(
      context.ordinal,
      i18n("discourse_post_event.builder_modal.recurrence.ordinals.last")
    );
  });

  test("falls back to the occurrence start without an inherited anchor", function (assert) {
    const event = DiscoursePostEventEvent.create({
      starts_at: "2027-04-26T12:00:00Z",
      timezone: "UTC",
      recurrence: "every_month",
    });

    assert.strictEqual(recurrenceRef(event).format("YYYY-MM-DD"), "2027-04-26");
  });

  test("uses a date-only anchor for all-day successor events", function (assert) {
    const event = DiscoursePostEventEvent.create({
      starts_at: "2027-04-26",
      recurrence_anchor_starts_at: "2027-03-29",
      all_day: true,
      recurrence: "every_month",
    });

    assert.strictEqual(recurrenceRef(event).format("YYYY-MM-DD"), "2027-03-29");
  });
});
