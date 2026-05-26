import { click, visit, waitFor } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

function noEventsPretender(server, helper) {
  server.get("/discourse-post-event/events", () => {
    return helper.response({ events: [] });
  });
}

const SETTINGS = {
  calendar_enabled: true,
  discourse_post_event_enabled: true,
  events_calendar_categories: "1",
  calendar_categories: "",
};

acceptance(
  "Calendar click to create - upcoming events (with permission)",
  function (needs) {
    needs.user({ can_create_discourse_post_event: true });
    needs.settings(SETTINGS);
    needs.pretender(noEventsPretender);

    test("clicking an empty day cell opens the composer with an all-day event at 9am", async function (assert) {
      await visit("/upcoming-events");
      await waitFor(".fc-day-today");

      const date = document
        .querySelector(".fc-day-today")
        .getAttribute("data-date");

      await click(".fc-day-today");
      await waitFor(".d-editor-input");

      assert
        .dom(".d-editor-input")
        .hasValue(
          new RegExp(
            `^\\[event start="${date} 09:00" status="public" timezone="[^"]+" end="${date} 10:00"\\]\\n\\[/event\\]\\n$`
          ),
          "composer opens with an all-day event defaulting to 9am for the clicked day"
        );
    });
  }
);

acceptance(
  "Calendar click to create - category (with permission)",
  function (needs) {
    needs.user({ can_create_discourse_post_event: true });
    needs.settings(SETTINGS);
    needs.pretender(noEventsPretender);

    test("clicking an empty day cell opens the composer prefilled with the category", async function (assert) {
      await visit("/c/bug/1");
      await waitFor(".fc-day-today");

      const date = document
        .querySelector(".fc-day-today")
        .getAttribute("data-date");

      await click(".fc-day-today");
      await waitFor(".d-editor-input");

      assert
        .dom(".d-editor-input")
        .hasValue(
          new RegExp(
            `^\\[event start="${date} 09:00" status="public" timezone="[^"]+" end="${date} 10:00"\\]\\n\\[/event\\]\\n$`
          ),
          "composer opens with an event for the clicked day"
        );

      assert.strictEqual(
        selectKit(".category-chooser").header().value(),
        "1",
        "the calendar's category is preselected in the composer"
      );
    });
  }
);

acceptance("Calendar click to create - no permission", function (needs) {
  needs.user({ can_create_discourse_post_event: false });
  needs.settings(SETTINGS);
  needs.pretender(noEventsPretender);

  test("clicking an empty day cell does nothing without event-create permission", async function (assert) {
    await visit("/upcoming-events");
    await waitFor(".fc-day-today");

    await click(".fc-day-today");

    assert
      .dom(".d-editor-input")
      .doesNotExist(
        "composer does not open when the user cannot create events"
      );
  });
});
