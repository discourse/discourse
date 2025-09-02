import Component from "@glimmer/component";
import { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import loadFullCalendar from "discourse/lib/load-full-calendar";
import DiscourseURL from "discourse/lib/url";
import DiscoursePostEvent from "discourse/plugins/discourse-calendar/discourse/components/discourse-post-event";
import {
  getCalendarButtonsText,
  getCurrentBcp47Locale,
} from "../lib/calendar-locale";
import { normalizeViewForCalendar } from "../lib/calendar-view-helper";

const PostEventMenu = <template>
  <DiscoursePostEvent
    @linkToPost={{true}}
    @event={{@data.event}}
    @eventId={{@data.eventId}}
    @onClose={{@data.onClose}}
    @withDescription={{false}}
    @currentEventStart={{@data.currentEventStart}}
  />
</template>;

export default class FullCalendar extends Component {
  @service currentUser;
  @service capabilities;
  @service tooltip;
  @service menu;
  @service siteSettings;
  @service loadingSlider;

  @controller topic;

  calendar = null;

  willDestroy() {
    this.calendar?.destroy?.();
    this.menu.getByIdentifier("post-event-menu")?.destroy?.();
    super.willDestroy(...arguments);
  }

  get firstDayOfWeek() {
    const setting = this.siteSettings.calendar_first_day_of_week;
    switch (setting) {
      case "saturday":
        return 6;
      case "sunday":
        return 0;
      case "monday":
      default:
        return 1;
    }
  }

  @action
  async setupCalendar(element) {
    const calendarModule = await loadFullCalendar();

    this.calendar = new calendarModule.Calendar(element, {
      locale: getCurrentBcp47Locale(),
      buttonText: getCalendarButtonsText(),
      timeZone: this.currentUser?.user_option?.timezone || "local",
      firstDay: this.firstDayOfWeek,
      displayEventTime: true,
      weekends: this.args.weekends ?? true,
      initialDate: this.args.initialDate,
      height: this.args.height ?? "100%",
      events: async (info, successCallback, failureCallback) => {
        if (this.args.onLoadEvents) {
          try {
            this.loadingSlider.transitionStarted();
            const events = await this.args.onLoadEvents(info);
            successCallback(events);
            this.loadingSlider.transitionEnded();
          } catch (error) {
            failureCallback(error);
          }
        }
      },
      plugins: [
        calendarModule.DayGrid,
        calendarModule.TimeGrid,
        calendarModule.List,
        calendarModule.RRULE,
        calendarModule.MomentTimezone,
      ],
      initialView: this.initialView,
      headerToolbar: this.headerToolbar,
      customButtons: this.args.customButtons || {},
      eventWillUnmount: async () => {
        await this.activeMenu?.close?.();
        await this.activeTooltip?.close?.();
      },
      datesSet: (info) => {
        this.args.onDatesChange?.(info);
      },
      eventMouseLeave: async () => {
        await this.activeTooltip?.close?.();
      },
      eventMouseEnter: async ({ el, event }) => {
        const { htmlContent } = event.extendedProps;

        if (htmlContent) {
          this.activeTooltip = await this.tooltip.show(el, {
            identifier: "post-event-tooltip",
            triggers: ["hover"],
            content: htmlSafe(
              // this is a workaround to allow linebreaks in the tooltip
              "<div>" + htmlContent + "</div>"
            ),
          });
        }
      },
      eventClick: async ({ el, event, jsEvent }) => {
        const { postNumber, postUrl, postEvent } = event.extendedProps;

        if (postEvent?.id) {
          jsEvent.preventDefault();

          this.activeMenu = await this.menu.show(
            {
              getBoundingClientRect() {
                return el.getBoundingClientRect();
              },
            },
            {
              identifier: "post-event-menu",
              component: PostEventMenu,
              modalForMobile: true,
              maxWidth: 500,
              data: {
                currentEventStart: event.start,
                eventId: postEvent.id,
                onClose: () => {
                  this.menu.getByIdentifier("post-event-menu")?.close?.();
                },
              },
            }
          );
        } else if (postUrl) {
          DiscourseURL.routeTo(postUrl);
        } else if (postNumber) {
          this.topic.send("jumpToPost", postNumber);
        }
      },
    });

    this.calendar.render();
  }

  @action
  updateCalendar() {
    if (this.calendar) {
      this.calendar.setOption("headerToolbar", this.headerToolbar);
    }
  }

  get defaultLeftHeaderToolbar() {
    return !this.capabilities.viewport.md ? "prev,next" : "prev,next today";
  }

  get headerToolbar() {
    return {
      left: this.args.leftHeaderToolbar ?? this.defaultLeftHeaderToolbar,
      center: this.args.centerHeaderToolbar ?? "title",
      right:
        this.args.rightHeaderToolbar ??
        "timeGridDay,timeGridWeek,dayGridMonth,listYear",
    };
  }

  get initialView() {
    const normalizedView = normalizeViewForCalendar(this.args.initialView);

    return (
      normalizedView ||
      (this.capabilities.viewport.sm ? "dayGridMonth" : "timeGridWeek")
    );
  }

  <template>
    <div
      {{didInsert this.setupCalendar}}
      {{didUpdate this.updateCalendar @events this.capabilities.viewport.md}}
      ...attributes
    >
      {{! The calendar will be rendered inside this div by the library }}
    </div>
  </template>
}
