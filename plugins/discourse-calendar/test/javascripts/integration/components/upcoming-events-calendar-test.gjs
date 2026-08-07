import { render, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import UpcomingEventsCalendar from "../../discourse/components/upcoming-events-calendar";

module("Integration | Component | UpcomingEventsCalendar", function (hooks) {
  setupRenderingTest(hooks, { stubRouter: true });

  test("renders events from the requested category", async function (assert) {
    const requests = [];

    pretender.get("/discourse-post-event/events", ({ queryParams }) => {
      requests.push(queryParams);

      if (queryParams.category_id === "2") {
        return response({ events: [eventForCategory(2, "Beauty event")] });
      }

      return response({ events: [] });
    });

    await render(
      <template>
        <UpcomingEventsCalendar
          @categoryId={{2}}
          @includeSubcategories={{true}}
          @initialDate="2026-07-01"
          @initialView="dayGridMonth"
          @updateRouteOnDatesChange={{false}}
        />
      </template>
    );

    await waitFor(".fc-event-title");

    assert
      .dom(".fc-event-title")
      .hasText(
        "Beauty event",
        "renders the event returned for the selected category"
      );

    assert.strictEqual(
      requests[0].category_id,
      "2",
      "category id is passed through to the event API"
    );
    assert.strictEqual(
      requests[0].include_subcategories,
      "true",
      "include subcategories is passed through to the event API"
    );
  });
});

function eventForCategory(categoryId, name) {
  return {
    id: categoryId,
    name,
    category_id: categoryId,
    timezone: "UTC",
    post: {
      id: categoryId,
      post_number: 1,
      topic: {
        id: categoryId,
        title: name,
      },
    },
    occurrences: [
      {
        starts_at: "2026-07-10T10:00:00.000Z",
        ends_at: "2026-07-10T11:00:00.000Z",
      },
    ],
  };
}
