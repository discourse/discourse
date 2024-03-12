import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import {
  downloadGoogle,
  downloadIcs,
  downloadOffice365,
} from "discourse/lib/download-calendar";

export default class downloadCalendar extends Component {
  @service currentUser;

  @tracked selectedCalendar = "ics";
  @tracked remember = false;

  @action
  downloadCalendar() {
    if (this.remember) {
      this.currentUser.set(
        "user_option.default_calendar",
        this.selectedCalendar
      );
      this.currentUser.save(["default_calendar"]);
    }
    if (this.selectedCalendar === "ics") {
      downloadIcs(
        this.args.model.calendar.title,
        this.args.model.calendar.dates,
        this.args.model.calendar.recurrenceRule
      );
    } else if (this.selectedCalendar === "google") {
      downloadGoogle(
        this.args.model.calendar.title,
        this.args.model.calendar.dates,
        this.args.model.calendar.recurrenceRule
      );
    } else if (this.selectedCalendar === "office365") {
      downloadOffice365(
        this.args.model.calendar.title,
        this.args.model.calendar.dates
      );
    }
    this.args.closeModal();
  }

  @action
  selectCalendar(calendar) {
    this.selectedCalendar = calendar;
  }
}
