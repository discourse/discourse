import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import PostCalendar from "../components/post-calendar";

function initializeDiscourseCalendar(api) {
  const site = api.container.lookup("service:site");
  const postCalendar = api.container.lookup("service:post-calendar");

  api.decorateCookedElement(
    (element, helper) => {
      const calendar = element.querySelector(".calendar");

      if (!calendar) {
        return;
      }

      // header is now generated in the component
      // remove the old header generated when cooking if it exists
      element.querySelector(".discourse-calendar-header")?.remove?.();

      const post = helper.getModel();
      const options = calendar.dataset;
      const staticEvents = parseStaticDates(calendar, post);

      calendar.innerHTML = "";

      helper.renderGlimmer(
        calendar,
        <template>
          <PostCalendar
            @post={{@data.post}}
            @options={{@data.options}}
            @staticEvents={{@data.staticEvents}}
            @height="650px"
          />
        </template>,
        {
          options,
          post,
          staticEvents,
        }
      );
    },
    {
      onlyStream: true,
      id: "discourse-calendar",
    }
  );

  function parseStaticDates(calendar) {
    const events = [];
    const paragraph = calendar.querySelector(":scope > p");
    paragraph?.innerHTML?.split("<br>")?.forEach((line) => {
      const tempDiv = document.createElement("div");
      tempDiv.innerHTML = line;
      const html = Array.from(tempDiv.childNodes);

      const dates = html.filter(
        (h) => h.nodeType === 1 && h.classList.contains("discourse-local-date")
      );
      const title = html[0] ? html[0].textContent.trim() : "";

      const from = _convertHtmlToDate(dates[0]);

      let to;
      if (dates[1]) {
        to = _convertHtmlToDate(dates[1]);
      }
      let event = _buildEventObject(from, to);
      event.title = title;
      events.push(event);
    });

    return events;
  }

  api.registerCustomPostMessageCallback("calendar_change", () => {
    postCalendar.refresh();
  });

  if (api.registerNotificationTypeRenderer) {
    api.registerNotificationTypeRenderer(
      "event_reminder",
      (NotificationTypeBase) => {
        return class extends NotificationTypeBase {
          get linkTitle() {
            if (this.notification.data.title) {
              return i18n(this.notification.data.title);
            } else {
              return super.linkTitle;
            }
          }

          get icon() {
            return "calendar-day";
          }

          get label() {
            return i18n(this.notification.data.message);
          }

          get description() {
            return this.notification.data.topic_title;
          }
        };
      }
    );
    api.registerNotificationTypeRenderer(
      "event_invitation",
      (NotificationTypeBase) => {
        return class extends NotificationTypeBase {
          get icon() {
            return "calendar-day";
          }

          get label() {
            if (
              this.notification.data.message ===
              "discourse_post_event.notifications.invite_user_predefined_attendance_notification"
            ) {
              return i18n(this.notification.data.message, {
                username: this.username,
                eventName:
                  this.notification.data.event_name ||
                  i18n("discourse_post_event.notifications.an_event"),
              });
            }
            return super.label;
          }

          get description() {
            return this.notification.data.topic_title;
          }
        };
      }
    );
  }

  function _convertHtmlToDate(html) {
    const date = html.dataset.date;

    if (!date) {
      return null;
    }

    const time = html.dataset.time;
    const timezone = html.dataset.timezone;
    let dateTime = date;
    if (time) {
      dateTime = `${dateTime} ${time}`;
    }

    return {
      weeklyRecurring: html.dataset.recurring === "1.weeks",
      dateTime: moment.tz(dateTime, timezone || "Etc/UTC"),
    };
  }

  function _buildEventObject(from, to) {
    const hasTimeSpecified = (d) => {
      if (!d) {
        return false;
      }
      return d.hours() !== 0 || d.minutes() !== 0 || d.seconds() !== 0;
    };

    const hasTime =
      hasTimeSpecified(to?.dateTime) || hasTimeSpecified(from?.dateTime);
    const dateFormat = hasTime ? "YYYY-MM-DD HH:mm:ssZ" : "YYYY-MM-DD";

    let event = {
      start: from.dateTime.format(dateFormat),
      allDay: false,
    };

    if (to) {
      if (hasTime) {
        event.end = to.dateTime.format(dateFormat);
      } else {
        event.end = to.dateTime.add(1, "days").format(dateFormat);
        event.allDay = true;
      }
    } else {
      event.allDay = true;
    }

    if (from.weeklyRecurring) {
      event.startTime = {
        hours: from.dateTime.hours(),
        minutes: from.dateTime.minutes(),
        seconds: from.dateTime.seconds(),
      };
      event.daysOfWeek = [from.dateTime.day()];
    }

    return event;
  }
}

export default {
  name: "discourse-calendar",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (siteSettings.calendar_enabled) {
      withPluginApi(initializeDiscourseCalendar);
    }
  },
};
