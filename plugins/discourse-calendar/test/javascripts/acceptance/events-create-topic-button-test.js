import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

const eventsPretender = (server, helper) => {
  server.get("/discourse-post-event/events", () => {
    return helper.response({ events: [] });
  });
};

acceptance(
  "Events Create Topic Button - allowed user in events category",
  function (needs) {
    needs.user({ can_create_discourse_post_event: true });
    needs.settings({
      calendar_enabled: true,
      discourse_post_event_enabled: true,
      events_calendar_categories: "1",
    });
    needs.pretender(eventsPretender);

    test("renames the button to New Event and swaps the icon", async function (assert) {
      await visit("/c/bug/1");

      assert
        .dom("#create-topic")
        .hasText(i18n("discourse_post_event.new_event"));
      assert.dom("#create-topic .d-icon-far-calendar-plus").exists();
    });

    test("keeps the default label and icon outside events categories", async function (assert) {
      await visit("/c/feature/2");

      assert.dom("#create-topic").hasText(i18n("topic.create"));
      assert.dom("#create-topic .d-icon-far-pen-to-square").exists();
    });

    test("updates label and icon when navigating between categories", async function (assert) {
      await visit("/c/feature/2");
      assert.dom("#create-topic").hasText(i18n("topic.create"));
      assert.dom("#create-topic .d-icon-far-pen-to-square").exists();

      await visit("/c/bug/1");
      assert
        .dom("#create-topic")
        .hasText(i18n("discourse_post_event.new_event"));
      assert.dom("#create-topic .d-icon-far-calendar-plus").exists();
    });
  }
);

acceptance(
  "Events Create Topic Button - user without permission",
  function (needs) {
    needs.user({ can_create_discourse_post_event: false });
    needs.settings({
      calendar_enabled: true,
      discourse_post_event_enabled: true,
      events_calendar_categories: "1",
    });
    needs.pretender(eventsPretender);

    test("keeps the default label and icon", async function (assert) {
      await visit("/c/bug/1");

      assert.dom("#create-topic").hasText(i18n("topic.create"));
      assert.dom("#create-topic .d-icon-far-pen-to-square").exists();
    });
  }
);
