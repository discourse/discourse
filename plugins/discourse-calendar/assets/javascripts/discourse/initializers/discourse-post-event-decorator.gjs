import { isTesting } from "discourse/lib/environment";
import { withPluginApi } from "discourse/lib/plugin-api";
import I18n, { i18n } from "discourse-i18n";
import DiscoursePostEvent from "discourse/plugins/discourse-calendar/discourse/components/discourse-post-event";
import DiscoursePostEventEvent from "discourse/plugins/discourse-calendar/discourse/models/discourse-post-event-event";
import guessDateFormat from "../lib/guess-best-date-format";

export function buildEventPreview(eventContainer) {
  eventContainer.innerHTML = "";
  eventContainer.classList.add("discourse-post-event-preview");

  const statusLocaleKey = `discourse_post_event.models.event.status.${
    eventContainer.dataset.status || "public"
  }.title`;
  if (I18n.lookup(statusLocaleKey, { locale: "en" })) {
    const statusContainer = document.createElement("div");
    statusContainer.classList.add("event-preview-status");
    statusContainer.innerText = i18n(statusLocaleKey);
    eventContainer.appendChild(statusContainer);
  }

  const datesContainer = document.createElement("div");
  datesContainer.classList.add("event-preview-dates");

  const startsAt = moment.tz(
    eventContainer.dataset.start,
    eventContainer.dataset.timezone || "UTC"
  );

  const endsAt =
    eventContainer.dataset.end &&
    moment.tz(
      eventContainer.dataset.end,
      eventContainer.dataset.timezone || "UTC"
    );

  const format = guessDateFormat(startsAt, endsAt);
  const guessedTz = isTesting() ? "UTC" : moment.tz.guess();

  let datesString = `<span class='start'>${startsAt
    .tz(guessedTz)
    .format(format)}</span>`;
  if (endsAt) {
    datesString += ` → <span class='end'>${endsAt
      .tz(guessedTz)
      .format(format)}</span>`;
  }
  datesContainer.innerHTML = datesString;

  eventContainer.appendChild(datesContainer);
}

function _invalidEventPreview(eventContainer) {
  eventContainer.classList.add(
    "discourse-post-event-preview",
    "alert",
    "alert-error"
  );
  eventContainer.classList.remove("discourse-post-event");
  eventContainer.innerText = i18n(
    "discourse_post_event.preview.more_than_one_event"
  );
}

function _decorateEventPreview(api, cooked) {
  const eventContainers = cooked.querySelectorAll(".discourse-post-event");

  eventContainers.forEach((eventContainer, index) => {
    if (index > 0) {
      _invalidEventPreview(eventContainer);
    } else {
      buildEventPreview(eventContainer);
    }
  });
}

function initializeDiscoursePostEventDecorator(api) {
  api.decorateCookedElement(
    (cooked, helper) => {
      if (cooked.classList.contains("d-editor-preview")) {
        _decorateEventPreview(api, cooked);
        return;
      }

      if (helper) {
        const post = helper.getModel();

        if (!post?.event) {
          return;
        }

        const postEventNode = cooked.querySelector(".discourse-post-event");

        if (!postEventNode) {
          return;
        }

        const wrapper = document.createElement("div");
        postEventNode.before(wrapper);

        const event = DiscoursePostEventEvent.create(post.event);

        helper.renderGlimmer(
          wrapper,
          <template><DiscoursePostEvent @event={{event}} /></template>
        );
      }
    },
    {
      id: "discourse-post-event-decorator",
    }
  );

  api.replaceIcon(
    "notification.discourse_post_event.notifications.invite_user_notification",
    "calendar-day"
  );

  api.replaceIcon(
    "notification.discourse_post_event.notifications.invite_user_auto_notification",
    "calendar-day"
  );

  api.replaceIcon(
    "notification.discourse_calendar.invite_user_notification",
    "calendar-day"
  );

  api.replaceIcon(
    "notification.discourse_post_event.notifications.invite_user_predefined_attendance_notification",
    "calendar-day"
  );

  api.replaceIcon(
    "notification.discourse_post_event.notifications.before_event_reminder",
    "calendar-day"
  );

  api.replaceIcon(
    "notification.discourse_post_event.notifications.after_event_reminder",
    "calendar-day"
  );

  api.replaceIcon(
    "notification.discourse_post_event.notifications.ongoing_event_reminder",
    "calendar-day"
  );
}

export default {
  name: "discourse-post-event-decorator",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (siteSettings.discourse_post_event_enabled) {
      withPluginApi("0.8.7", initializeDiscoursePostEventDecorator);
    }
  },
};
