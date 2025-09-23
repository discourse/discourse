import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import getURL from "discourse/lib/get-url";
import { escapeExpression } from "discourse/lib/utilities";
import { colorToHex, contrastColor, stringToColor } from "../lib/colors";
import FullCalendar from "./full-calendar";

export default class PostCalendar extends Component {
  @service currentUser;
  @service siteSettings;
  @service capabilities;
  @service postCalendar;
  @service store;

  @tracked post = this.args.post;

  @action
  registerPostCalendar() {
    this.postCalendar.registerComponent(this);
  }

  @action
  teardownPostCalendar() {
    this.postCalendar.teardownComponent();
  }

  get isStatic() {
    return this.args.options.calendarType === "static";
  }

  get isFullDay() {
    return this.args.options.calendarFullDay === "true";
  }

  @action
  loadEvents() {
    const events = [];

    if (this.isStatic) {
      events.push(...(this.args.staticEvents ?? []));
    } else {
      events.push(...(this.dynamicEvents ?? []));
    }

    return events;
  }

  get dynamicEvents() {
    const events = [];
    const groupedEvents = [];

    (this.post.calendar_details || []).forEach((detail) => {
      switch (detail.type) {
        case "grouped":
          if (this.isFullDay && detail.timezone) {
            detail.from = moment
              .tz(detail.from, detail.timezone)
              .format("YYYY-MM-DD");
          }
          groupedEvents.push(detail);
          break;
        case "standalone":
          if (this.isFullDay && detail.timezone) {
            const eventDetail = { ...detail };
            const from = moment.tz(detail.from, detail.timezone);
            const to = moment.tz(detail.to, detail.timezone);
            eventDetail.from = from.format("YYYY-MM-DD");
            eventDetail.to = to.format("YYYY-MM-DD");
            events.push(this.buildStandaloneEvent(eventDetail));
          } else {
            events.push(this.buildStandaloneEvent(detail));
          }
          break;
      }
    });

    const formattedGroupedEvents = {};
    groupedEvents.forEach((groupedEvent) => {
      const minDate = this.isFullDay
        ? moment(groupedEvent.from).format("YYYY-MM-DD")
        : moment(groupedEvent.from).utc().startOf("day").toISOString();
      const maxDate = this.isFullDay
        ? moment(groupedEvent.to || groupedEvent.from).format("YYYY-MM-DD")
        : moment(groupedEvent.to || groupedEvent.from)
            .utc()
            .endOf("day")
            .toISOString();

      const identifier = `${minDate}-${maxDate}`;
      formattedGroupedEvents[identifier] = formattedGroupedEvents[
        identifier
      ] || {
        from: minDate,
        to: maxDate || minDate,
        localEvents: {},
      };

      formattedGroupedEvents[identifier].localEvents[groupedEvent.name] =
        formattedGroupedEvents[identifier].localEvents[groupedEvent.name] || {
          users: [],
        };

      formattedGroupedEvents[identifier].localEvents[
        groupedEvent.name
      ].users.push.apply(
        formattedGroupedEvents[identifier].localEvents[groupedEvent.name].users,
        groupedEvent.users
      );
    });

    Object.keys(formattedGroupedEvents).forEach((key) => {
      const formattedGroupedEvent = formattedGroupedEvents[key];
      this.buildGroupedEvents(formattedGroupedEvent).forEach((event) => {
        events.push(event);
      });
    });

    return events;
  }

  buildEvent(detail) {
    const event = this.buildEventObject(
      detail.from
        ? {
            dateTime: moment(detail.from),
            weeklyRecurring: detail.recurring === "1.weeks",
          }
        : null,
      detail.to
        ? {
            dateTime: moment(detail.to),
            weeklyRecurring: detail.recurring === "1.weeks",
          }
        : null
    );

    event.extendedProps = {};
    if (detail.post_url) {
      event.extendedProps.postUrl = getURL(detail.post_url);
    } else if (detail.post_number) {
      event.extendedProps.postNumber = detail.post_number;
    } else {
      event.classNames = ["holiday"];
    }

    if (detail.timezoneOffset) {
      event.extendedProps.timezoneOffset = detail.timezoneOffset;
    }

    return event;
  }

  buildEventObject(from, to) {
    const hasTimeSpecified = (d) => {
      if (!d) {
        return false;
      }
      return d.hours() || d.minutes() || d.seconds();
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

  buildGroupedEvents(detail) {
    const events = [];
    const groupedEventData = [detail];

    groupedEventData.forEach((eventData) => {
      let htmlContent = "";
      let users = [];
      let localEventNames = [];

      Object.keys(eventData.localEvents)
        .sort()
        .forEach((key) => {
          const localEvent = eventData.localEvents[key];
          htmlContent += `<b>${key}</b>: ${localEvent.users
            .map((u) => u.username)
            .sort()
            .join(", ")}<br>`;
          users = users.concat(localEvent.users);
          localEventNames.push(key);
        });

      const event = this.buildEvent(eventData);
      event.classNames = ["grouped-event"];

      if (users.length > 2) {
        event.title = `(${users.length}) ${localEventNames[0]}`;
      } else if (users.length === 1) {
        event.title = users[0].username;
      } else {
        event.title = !this.capabilities.viewport.sm
          ? `(${users.length}) ${localEventNames[0]}`
          : `(${users.length}) ` + users.map((u) => u.username).join(", ");
      }

      if (localEventNames.length > 1) {
        event.extendedProps.htmlContent = htmlContent;
      } else {
        if (users.length > 1) {
          event.extendedProps.htmlContent = htmlContent;
        } else {
          event.extendedProps.htmlContent = localEventNames[0];
        }
      }

      event.participantCount = users.length;
      events.push(event);
    });

    return events;
  }

  buildStandaloneEvent(detail) {
    const event = this.buildEvent(detail);
    const holidayCalendarTopicId = parseInt(
      this.siteSettings.holiday_calendar_topic_id,
      10
    );
    const text = detail.message.split("\n").filter(Boolean);

    if (
      text.length &&
      this.args.post.topic_id &&
      holidayCalendarTopicId !== this.args.post.topic_id
    ) {
      event.title = text[0];
      event.extendedProps.description = text.slice(1).join(" ");
    } else {
      const color = stringToColor(detail.username);
      event.title = detail.username;
      event.backgroundColor = colorToHex(color);
      event.textColor = contrastColor(color);
    }

    let popupText = detail.message.slice(0, 100);
    if (detail.message.length > 100) {
      popupText += "…";
    }
    event.extendedProps.htmlContent = htmlSafe(escapeExpression(popupText));
    event.title = event.title.replace(/<img[^>]*>/g, "");
    event.participantCount = 1;

    if (detail.post_url) {
      event.extendedProps.postUrl = getURL(detail.post_url);
    }

    return event;
  }

  get leftHeaderToolbar() {
    return this.capabilities.viewport.sm
      ? "prev,next today"
      : "prev,next title";
  }

  get centerHeaderToolbar() {
    return this.capabilities.viewport.sm ? "title" : "";
  }

  <template>
    <div
      {{didInsert this.registerPostCalendar}}
      {{willDestroy this.teardownPostCalendar}}
      class="post-calendar"
    >
      <FullCalendar
        @leftHeaderToolbar={{this.leftHeaderToolbar}}
        @centerHeaderToolbar={{this.centerHeaderToolbar}}
        @rightHeaderToolbar="timeGridDay,timeGridWeek,dayGridMonth,listYear"
        @onLoadEvents={{this.loadEvents}}
        @height={{@height}}
      />
    </div>
  </template>
}
