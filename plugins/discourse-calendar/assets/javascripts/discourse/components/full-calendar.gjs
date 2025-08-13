import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import loadFullCalendar from "discourse/lib/load-full-calendar";
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
      eventDisplay: "block",
      weekends: this.args.weekends ?? true,
      height: this.args.height ?? "100%",
      plugins: [
        calendarModule.DayGrid,
        calendarModule.TimeGrid,
        calendarModule.List,
        calendarModule.RRULE,
        calendarModule.MomentTimezone,
      ],
      views: {
        dayGridMonth: {
          displayEventTime: false,
        },
      },
      initialView: this.initialView,
      events: this.args.events || [],
      headerToolbar: this.headerToolbar,
      customButtons: this.args.customButtons || {},
      eventWillUnmount: (info) => {
        if (info.event.extendedProps?.tooltip) {
          info.event.extendedProps?.tooltip.destroy();
        }
      },
      datesSet: (info) => {
        if (this.args.onDatesChange) {
          this.args.onDatesChange(info);
        }
      },
      eventDidMount: (info) => {
        if (info.event.extendedProps?.htmlContent) {
          const tooltip = this.tooltip.register(info.el, {
            content: info.event.extendedProps.htmlContent,
          });

          info.event.setExtendedProp("tooltip", tooltip);
        }
      },
      eventClick: async (info) => {
        info.jsEvent.preventDefault();

        const menu = await this.menu.show(
          {
            getBoundingClientRect() {
              return info.el.getBoundingClientRect();
            },
          },
          {
            identifier: "post-event-menu",
            component: PostEventMenu,
            modalForMobile: true,
            maxWidth: 500,
            data: {
              eventId: info.event.extendedProps.postEvent.id,
              onClose: () => {
                this.menu.getByIdentifier("post-event-menu")?.close?.();
              },
            },
          }
        );

        info.event.setExtendedProp("menu", menu);
      },
    });

    this.calendar.render();
  }

  @action
  updateCalendar() {
    if (this.calendar) {
      this.calendar.setOption("events", this.args.events || []);
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
