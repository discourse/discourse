import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, queryAll } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("Discourse Calendar - Notifications", function (needs) {
  needs.user({ redesigned_user_menu_enabled: true });
  needs.settings({ calendar_enabled: true });

  needs.pretender((server, helper) => {
    server.get("/notifications", () => {
      return helper.response({
        notifications: [
          {
            id: 8832,
            user_id: 12,
            notification_type: 27,
            read: true,
            high_priority: false,
            created_at: "2021-01-07 13:31:10 UTC",
            post_number: 1,
            topic_id: 993,
            fancy_title: "Monthly Hangout #3",
            slug: "monthly-hangout-3",
            data: {
              topic_title: "Monthly Hangout #3",
              display_username: "fun-haver",
              message:
                "discourse_post_event.notifications.before_event_reminder",
            },
          },
          {
            id: 123,
            user_id: 12,
            notification_type: 27,
            read: true,
            high_priority: false,
            created_at: "2021-04-26 13:00:02 UTC",
            post_number: 1,
            topic_id: 339,
            fancy_title: "Fancy title and pants",
            slug: "fancy-title-and-pants",
            data: {
              topic_title: "Fancy title and pants",
              display_username: "fancy-pants-wearer",
              message:
                "discourse_post_event.notifications.ongoing_event_reminder",
            },
          },
          {
            id: 88844,
            user_id: 12,
            notification_type: 27,
            read: true,
            high_priority: false,
            created_at: "2021-09-23 01:40:51 UTC",
            post_number: 1,
            topic_id: 834,
            fancy_title: "Topic with event and after_event reminder",
            slug: "topic-with-event-and-after_event-reminder",
            data: {
              topic_title: "Topic with event and after_event reminder",
              display_username: "attender-no193",
              message:
                "discourse_post_event.notifications.after_event_reminder",
            },
          },
          {
            id: 7542,
            user_id: 12,
            notification_type: 28,
            read: true,
            high_priority: false,
            created_at: "2020-10-06 21:00:01 UTC",
            post_number: 1,
            topic_id: 195,
            fancy_title: "Tuesdays are for Among Us",
            slug: "tuesdays-are-for-among-us",
            data: {
              topic_title: "Tuesdays are for Among Us",
              display_username: "imposter",
              message:
                "discourse_post_event.notifications.invite_user_notification",
            },
          },
          {
            id: 9034,
            user_id: 12,
            notification_type: 28,
            read: true,
            high_priority: false,
            created_at: "2022-03-11 02:59:25 UTC",
            post_number: 1,
            topic_id: 348,
            fancy_title: "Asia Pacific team call",
            slug: "asia-pacific-team-call",
            data: {
              topic_title: "Asia Pacific team call",
              display_username: "apacer",
              message:
                "discourse_post_event.notifications.invite_user_predefined_attendance_notification",
            },
          },
        ],
      });
    });
  });

  test("event reminder and invitation notifications", async function (assert) {
    await visit("/");
    await click(".d-header-icons .current-user button");

    const notifications = queryAll(
      "#quick-access-all-notifications ul li.notification a"
    );
    assert.strictEqual(notifications.length, 5);

    assert.strictEqual(
      notifications[0].textContent.replaceAll(/\s+/g, " ").trim(),
      `${i18n(
        "discourse_post_event.notifications.before_event_reminder"
      )} Monthly Hangout #3`,
      "before event reminder notification has the right content"
    );
    assert.true(
      notifications[0].href.endsWith("/t/monthly-hangout-3/993"),
      "before event reminder notification links to the event topic"
    );
    assert
      .dom(".d-icon-calendar-day", notifications[0])
      .exists("before event reminder notification has the right icon");

    assert.strictEqual(
      notifications[1].textContent.replaceAll(/\s+/g, " ").trim(),
      `${i18n(
        "discourse_post_event.notifications.ongoing_event_reminder"
      )} Fancy title and pants`,
      "ongoing event reminder notification has the right content"
    );
    assert.true(
      notifications[1].href.endsWith("/t/fancy-title-and-pants/339"),
      "ongoing event reminder notification links to the event topic"
    );
    assert
      .dom(".d-icon-calendar-day", notifications[1])
      .exists("ongoing event reminder notification has the right icon");

    assert.strictEqual(
      notifications[2].textContent.replaceAll(/\s+/g, " ").trim(),
      `${i18n(
        "discourse_post_event.notifications.after_event_reminder"
      )} Topic with event and after_event reminder`,
      "after event reminder notification has the right content"
    );
    assert.true(
      notifications[2].href.endsWith(
        "/t/topic-with-event-and-after_event-reminder/834"
      ),
      "after event reminder notification links to the event topic"
    );
    assert
      .dom(".d-icon-calendar-day", notifications[2])
      .exists("after event reminder notification has the right icon");

    assert.strictEqual(
      notifications[3].textContent.replaceAll(/\s+/g, " ").trim(),
      "imposter Tuesdays are for Among Us",
      "event invitation notification has the right content"
    );
    assert.true(
      notifications[3].href.endsWith("/t/tuesdays-are-for-among-us/195"),
      "event invitation notification links to the event topic"
    );
    assert
      .dom(".d-icon-calendar-day", notifications[3])
      .exists("event invitation notification has the right icon");

    assert.strictEqual(
      notifications[4].textContent.replaceAll(/\s+/g, " ").trim(),
      `${i18n(
        "discourse_post_event.notifications.invite_user_predefined_attendance_notification",
        { username: "apacer" }
      )} Asia Pacific team call`,
      "event invitation with predefined attendance notification has the right content"
    );
    assert.true(
      notifications[4].href.endsWith("/t/asia-pacific-team-call/348"),
      "event invitation with predefined attendance notification links to the event topic"
    );
    assert
      .dom(".d-icon-calendar-day", notifications[4])
      .exists(
        "event invitation with predefined attendance notification has the right icon"
      );
  });
});
