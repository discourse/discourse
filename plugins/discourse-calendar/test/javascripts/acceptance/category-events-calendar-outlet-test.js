import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const eventsPretender = (server, helper) => {
  server.get("/discourse-post-event/events", () => {
    return helper.response({
      events: [
        {
          id: 67501,
          starts_at: "2022-04-25T15:14:00.000Z",
          ends_at: "2022-04-30T16:14:00.000Z",
          timezone: "Asia/Calcutta",
          post: {
            id: 67501,
            post_number: 1,
            url: "/t/this-is-an-event/18449/1",
            topic: {
              id: 18449,
              title: "This is an event",
              tags: ["awesome-event"],
            },
          },
          name: "Awesome Event",
        },
      ],
    });
  });
};

acceptance(
  "Discourse Calendar - Category Events Calendar Outlet None",
  function (needs) {
    needs.user();
    needs.settings({
      calendar_enabled: true,
      discourse_post_event_enabled: true,
      events_calendar_categories: "1",
      calendar_categories: "",
      calendar_categories_outlet: "none",
    });

    needs.pretender(eventsPretender);

    test("don't display calendars if outlet option is none", async function (assert) {
      await visit("/c/bug/1");

      assert
        .dom("#category-events-calendar")
        .doesNotExist("Category Events calendar div does not exist");

      assert
        .dom(".category-calendar")
        .doesNotExist("Category calendar div does not exist");
    });
  }
);

acceptance(
  "Discourse Calendar - Category Events Calendar Outlet Container Top",
  function (needs) {
    needs.user();
    needs.settings({
      calendar_enabled: true,
      discourse_post_event_enabled: true,
      events_calendar_categories: "1",
      calendar_categories: "",
      calendar_categories_outlet: "discovery-list-container-top",
    });

    needs.pretender(eventsPretender);

    test("display the specific calendar for the discovery-list-container-top outlet", async function (assert) {
      await visit("/c/bug/1");

      assert
        .dom("#category-events-calendar")
        .exists("Category Events calendar div exists");

      assert
        .dom(".category-calendar")
        .doesNotExist("Category calendar div does not exist");
    });
  }
);

acceptance(
  "Discourse Calendar - Category Events Calendar Outlet Container before-topic-list-body",
  function (needs) {
    needs.user();
    needs.settings({
      calendar_enabled: true,
      discourse_post_event_enabled: true,
      events_calendar_categories: "1",
      calendar_categories: "",
      calendar_categories_outlet: "before-topic-list-body",
    });

    needs.pretender(eventsPretender);

    test("display the specific calendar for before-topic-list-body outlet", async function (assert) {
      await visit("/c/bug/1");

      assert.dom("#category-events-calendar.--before-topic-list-body").exists();
    });
  }
);

acceptance(
  "Discourse Calendar - Category Events Calendar Outlet Container discovery-list-container-top",
  function (needs) {
    needs.user();
    needs.settings({
      calendar_enabled: true,
      discourse_post_event_enabled: true,
      events_calendar_categories: "1",
      calendar_categories: "",
      calendar_categories_outlet: "discovery-list-container-top",
    });

    needs.pretender(eventsPretender);

    test("display the specific calendar for discovery-list-container-top outlet", async function (assert) {
      await visit("/c/bug/1");

      assert
        .dom("#category-events-calendar.--discovery-list-container-top")
        .exists();
    });
  }
);
