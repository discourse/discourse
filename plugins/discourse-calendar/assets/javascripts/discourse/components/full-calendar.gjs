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

const PostEventMenu = <template>
  <DiscoursePostEvent
    @linkToPost={{true}}
    @event={{@data.event}}
    @eventId={{@data.eventId}}
    @onClose={{@data.onClose}}
    @withDescription={{false}}
  />
</template>;

export default class FullCalendar extends Component {
  @service currentUser;
  @service capabilities;
  @service tooltip;
  @service menu;

  @controller topic;

  calendar = null;

  willDestroy() {
    this.calendar?.destroy?.();
    this.menu.getByIdentifier("post-event-menu")?.destroy?.();
    super.willDestroy(...arguments);
  }

  @action
  async setupCalendar(element) {
    const calendarModule = await loadFullCalendar();

    this.calendar = new calendarModule.Calendar(element, {
      locale: getCurrentBcp47Locale(),
      buttonText: getCalendarButtonsText(),
      timeZone: this.currentUser?.user_option?.timezone || "local",
      firstDay: 1,
      displayEventTime: true,
      weekends: this.args.weekends ?? true,
      initialDate: this.args.initialDate,
      height: this.args.height ?? "100%",
      plugins: [
        calendarModule.DayGrid,
        calendarModule.TimeGrid,
        calendarModule.List,
        calendarModule.RRULE,
        calendarModule.MomentTimezone,
      ],
      initialView: this.initialView,
      eventSources: [
        {
          events: (info, successCallback) => {
            successCallback(this.args.events || []);
          },
        },
      ],
      headerToolbar: this.headerToolbar,
      customButtons: this.args.customButtons || {},
      eventWillUnmount: () => {
        this.menu.getByIdentifier("post-event-menu")?.close?.();
        this.menu.getByIdentifier("post-event-tooltip")?.close?.();
      },
      datesSet: (info) => {
        this.args.onDatesChange?.(info);
      },
      eventClick: async ({ el, event, jsEvent }) => {
        const { htmlContent, postNumber, postUrl, postEvent } =
          event.extendedProps;

        if (postUrl) {
          DiscourseURL.routeTo(postUrl);
        } else if (postNumber) {
          this.topic.send("jumpToPost", postNumber);
        } else if (htmlContent) {
          this.tooltip.show(el, {
            identifier: "post-event-tooltip",
            triggers: ["hover"],
            content: htmlSafe(
              // this is a workaround to allow linebreaks in the tooltip
              "<div>" + event.extendedProps.htmlContent + "</div>"
            ),
          });
        } else if (postEvent.id) {
          jsEvent.preventDefault();

          await this.menu.show(
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
                eventId: postEvent.id,
                onClose: () => {
                  this.menu.getByIdentifier("post-event-menu")?.close?.();
                },
              },
            }
          );
        }
      },
    });

    this.calendar.render();
  }

  @action
  updateCalendar() {
    if (this.calendar) {
      this.calendar.refetchEvents();
      this.calendar.setOption("headerToolbar", this.headerToolbar);
      if (this.args.initialDate) {
        this.calendar.gotoDate(this.args.initialDate);
      }
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
    let initialView = this.args.initialView;
    if (initialView === "agendaDay") {
      initialView = "timeGridDay";
    } else if (initialView === "agendaWeek") {
      initialView = "timeGridWeek";
    } else if (initialView === "month") {
      initialView = "dayGridMonth";
    } else if (initialView === "listNextYear") {
      initialView = "listYear";
    }

    return (
      this.args.initialView ||
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
