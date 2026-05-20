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
