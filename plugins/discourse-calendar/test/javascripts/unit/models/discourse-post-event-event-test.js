import { module, test } from "qunit";
import DiscoursePostEventEvent from "../../discourse/models/discourse-post-event-event";

module("Unit | Model | DiscoursePostEventEvent", function () {
  test("maps description fields from API response", function (assert) {
    const event = DiscoursePostEventEvent.create({
      id: 1,
      description: "Visit https://example.com",
      description_html:
        'Visit <a href="https://example.com">https://example.com</a>',
    });

    assert.strictEqual(event.description, "Visit https://example.com");
    assert.strictEqual(
      event.descriptionHtml,
      'Visit <a href="https://example.com">https://example.com</a>'
    );
  });

  test("pastEventTimeframe allows a grace period after the end time", function (assert) {
    const endedRecently = DiscoursePostEventEvent.create({
      id: 1,
      ends_at: moment().subtract(5, "minutes").toISOString(),
    });
    const endedLongAgo = DiscoursePostEventEvent.create({
      id: 2,
      ends_at: moment().subtract(15, "minutes").toISOString(),
    });
    const noEndTime = DiscoursePostEventEvent.create({ id: 3 });

    assert.false(
      endedRecently.pastEventTimeframe,
      "still within the grace period"
    );
    assert.true(endedLongAgo.pastEventTimeframe, "past the grace period");
    assert.false(
      noEndTime.pastEventTimeframe,
      "an event without an end time never ends"
    );
  });

  test("updateFromEvent copies description fields", function (assert) {
    const event = DiscoursePostEventEvent.create({ id: 1 });
    const updated = DiscoursePostEventEvent.create({
      id: 1,
      description: "Visit https://example.com",
      description_html:
        'Visit <a href="https://example.com">https://example.com</a>',
    });

    event.updateFromEvent(updated);

    assert.strictEqual(event.description, "Visit https://example.com");
    assert.strictEqual(
      event.descriptionHtml,
      'Visit <a href="https://example.com">https://example.com</a>'
    );
  });
});
