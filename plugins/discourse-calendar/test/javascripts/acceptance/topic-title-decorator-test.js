import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import { cloneJSON } from "discourse/lib/object";
import discoveryFixtures from "discourse/tests/fixtures/discovery-fixtures";
import { acceptance, queryAll } from "discourse/tests/helpers/qunit-helpers";

acceptance("Discourse Calendar - Event Title Decorator", function (needs) {
  needs.user();
  needs.settings({
    calendar_enabled: true,
    discourse_post_event_enabled: true,
  });

  needs.pretender((server, helper) => {
    server.get("/latest.json", () => {
      const topicList = cloneJSON(discoveryFixtures["/latest.json"]);

      // both start and end dates
      topicList.topic_list.topics[0].event_starts_at = "2022-01-10 19:00:00";
      topicList.topic_list.topics[0].event_ends_at = "2022-01-10 20:00:00";
      // just a start date
      topicList.topic_list.topics[1].event_starts_at = "2022-01-11 15:00:00";

      return helper.response(topicList);
    });
  });

  test("shows event date with attributes in topic list", async (assert) => {
    sinon.stub(moment.tz, "guess");
    moment.tz.guess.returns("UTC");
    moment.tz.setDefault("UTC");

    await visit("/latest");

    const topics = queryAll(".topic-list-item");

    assert.dom(".event-date.past", topics[0]).exists();
    assert.dom(".event-date", topics[0]).hasAttribute("data-starts-at");
    assert.dom(".event-date", topics[0]).hasAttribute("data-ends-at");
    assert
      .dom(".event-date", topics[0])
      .hasAttribute(
        "title",
        "January 10, 2022 7:00 PM → January 10, 2022 8:00 PM"
      );

    assert.dom(".event-date.past", topics[1]).exists();
    assert.dom(".event-date", topics[1]).hasAttribute("data-starts-at");
    assert.dom(".event-date", topics[1]).hasAttribute("data-ends-at");
    assert
      .dom(".event-date", topics[1])
      .hasAttribute("title", "January 11, 2022 3:00 PM");
  });
});
