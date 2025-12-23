import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance(
  "Discourse Calendar - Category Events Calendar Navigation",
  function (needs) {
    needs.user();
    needs.settings({
      calendar_enabled: true,
      discourse_post_event_enabled: true,
      events_calendar_categories: "1|2",
    });

    let eventCalls = [];

    needs.pretender((server, helper) => {
      server.get("/discourse-post-event/events", (request) => {
        eventCalls.push(request.queryParams);
        const categoryId = request.queryParams.category_id;

        return helper.response({
          events: [
            {
              id: 100 + parseInt(categoryId, 10),
              starts_at: moment().add(1, "days").toISOString(),
              ends_at: moment().add(1, "days").add(1, "hours").toISOString(),
              post: {
                id: 200 + parseInt(categoryId, 10),
                post_number: 1,
                url: `/t/event-in-cat-${categoryId}/1/1`,
                topic: {
                  id: 300 + parseInt(categoryId, 10),
                  title: `Event in Cat ${categoryId}`,
                },
              },
              name: `Event in Cat ${categoryId}`,
              category_id: parseInt(categoryId, 10),
              occurrences: [
                {
                  starts_at: moment().add(1, "days").toISOString(),
                  ends_at: moment()
                    .add(1, "days")
                    .add(1, "hours")
                    .toISOString(),
                },
              ],
            },
          ],
        });
      });
    });

    test("reloads events when navigating between categories", async function (assert) {
      await visit("/c/bug/1");

      assert.true(
        eventCalls.some((call) => call.category_id === "1"),
        "Fetched events for category 1"
      );
      assert.dom(".fc-event-title").hasText("Event in Cat 1");

      eventCalls = [];
      await visit("/c/feature/2");

      assert.true(
        eventCalls.some((call) => call.category_id === "2"),
        "Fetched events for category 2 after navigation"
      );
      assert.dom(".fc-event-title").hasText("Event in Cat 2");
    });
  }
);
