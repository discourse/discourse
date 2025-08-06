import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { LinkTo } from "@ember/routing";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { Promise } from "rsvp";
import getURL from "discourse/lib/get-url";
import loadScript from "discourse/lib/load-script";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";
import { formatEventName } from "../helpers/format-event-name";
import addRecurrentEvents from "../lib/add-recurrent-events";
import fullCalendarDefaultOptions from "../lib/full-calendar-default-options";
import { isNotFullDayEvent } from "../lib/guess-best-date-format";

export default class UpcomingEventsCalendar extends Component {
  @service currentUser;
  @service site;
  @service router;

  _calendar = null;

  get displayFilters() {
    return this.currentUser && this.args.controller;
  }

  @action
  teardown() {
    this._calendar?.destroy?.();
    this._calendar = null;
  }

  @action
  async renderCalendar() {
    const siteSettings = this.site.siteSettings;
    const isMobileView = this.site.mobileView;

    const calendarNode = document.getElementById("upcoming-events-calendar");
    if (!calendarNode) {
      return;
    }

    calendarNode.innerHTML = "";

    await this._loadCalendar();

    const view =
      this.args.controller?.view || (isMobileView ? "listNextYear" : "month");

    const fullCalendar = new window.FullCalendar.Calendar(calendarNode, {
      ...fullCalendarDefaultOptions(),
      timeZone: this.currentUser?.user_option?.timezone || "local",
      firstDay: 1,
      height: "auto",
      defaultView: view,
      views: {
        listNextYear: {
          type: "list",
          duration: { days: 365 },
          buttonText: "list",
          listDayFormat: {
            month: "long",
            year: "numeric",
            day: "numeric",
            weekday: "long",
          },
        },
      },
      header: {
        left: "prev,next today",
        center: "title",
        right: "month,basicWeek,listNextYear",
      },
      datesRender: (info) => {
        // this is renamed in FullCalendar v5 / v6 to datesSet
        // in unit tests we skip
        if (this.router?.transitionTo) {
          this.router.transitionTo({ queryParams: { view: info.view.type } });
        }
      },
      eventPositioned: (info) => {
        if (siteSettings.events_max_rows === 0) {
          return;
        }

        let fcContent = info.el.querySelector(".fc-content");

        if (!fcContent) {
          return;
        }

        let computedStyle = window.getComputedStyle(fcContent);
        let lineHeight = parseInt(computedStyle.lineHeight, 10);

        if (lineHeight === 0) {
          lineHeight = 20;
        }
        let maxHeight = lineHeight * siteSettings.events_max_rows;

        if (fcContent) {
          fcContent.style.maxHeight = `${maxHeight}px`;
        }

        let fcTitle = info.el.querySelector(".fc-title");
        if (fcTitle) {
          fcTitle.style.overflow = "hidden";
          fcTitle.style.whiteSpace = "pre-wrap";
        }
        fullCalendar.updateSize();
      },
    });
    this._calendar = fullCalendar;

    const tagsColorsMap = JSON.parse(siteSettings.map_events_to_color);

    const resolvedEvents = this.args.events
      ? await this.args.events
      : await this.args.controller.model;
    const originalEventAndRecurrents = addRecurrentEvents(resolvedEvents);

    (originalEventAndRecurrents || []).forEach((event) => {
      const { startsAt, endsAt, post, categoryId } = event;

      let backgroundColor;

      if (post.topic.tags) {
        const tagColorEntry = tagsColorsMap.find(
          (entry) =>
            entry.type === "tag" && post.topic.tags.includes(entry.slug)
        );
        backgroundColor = tagColorEntry?.color;
      }

      if (!backgroundColor) {
        const categoryColorEntry = tagsColorsMap.find(
          (entry) =>
            entry.type === "category" && entry.slug === post.topic.category_slug
        );
        backgroundColor = categoryColorEntry?.color;
      }

      const categoryColor = Category.findById(categoryId)?.color;
      if (!backgroundColor && categoryColor) {
        backgroundColor = `#${categoryColor}`;
      }

      let classNames;
      if (moment(endsAt || startsAt).isBefore(moment())) {
        classNames = "fc-past-event";
      }

      this._calendar.addEvent({
        title: formatEventName(event, this.currentUser?.user_option?.timezone),
        start: startsAt,
        end: endsAt || startsAt,
        allDay: !isNotFullDayEvent(moment(startsAt), moment(endsAt)),
        url: getURL(`/t/-/${post.topic.id}/${post.post_number}`),
        backgroundColor,
        classNames,
      });
    });

    this._calendar.render();
  }

  _loadCalendar() {
    return new Promise((resolve) => {
      loadScript(
        "/plugins/discourse-calendar/javascripts/fullcalendar-with-moment-timezone.min.js"
      ).then(() => {
        schedule("afterRender", () => {
          if (this.isDestroying || this.isDestroyed) {
            return;
          }

          resolve();
        });
      });
    });
  }

  <template>
    {{#if this.displayFilters}}
      <ul class="events-filter nav nav-pills">
        <li>
          <LinkTo
            @route="discourse-post-event-upcoming-events.index"
            class="btn-small"
          >
            {{i18n "discourse_post_event.upcoming_events.all_events"}}
          </LinkTo>
        </li>
        <li>
          <LinkTo
            @route="discourse-post-event-upcoming-events.mine"
            class="btn-small"
          >
            {{i18n "discourse_post_event.upcoming_events.my_events"}}
          </LinkTo>
        </li>
      </ul>
    {{/if}}

    <div
      id="upcoming-events-calendar"
      {{didInsert this.renderCalendar}}
      {{willDestroy this.teardown}}
    ></div>
  </template>
}
