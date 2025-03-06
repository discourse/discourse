import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DatePicker from "discourse/components/date-picker";
import withEventValue from "discourse/helpers/with-event-value";

export default class FKControlCalendar extends Component {
  static controlType = "calendar";

  @service site;

  get containerId() {
    return `${this.args.field.name}-${this.args.field.id}-container`;
  }

  get time() {
    console.log(
      this.args.field.value,
      moment(this.args.field.value).format("HH:mm")
    );
    return this.args.field.value
      ? moment(this.args.field.value).format("HH:mm")
      : null;
  }

  get includeTime() {
    return this.args.includeTime ?? true;
  }

  @action
  setTime(time) {
    console.log("set time", time);
    // const [hours, minutes] = time.split(":").map(Number);
    // const updatedDate = this.args.field.value || new Date();
    // updatedDate.setHours(hours, minutes);
    // this.args.field.set(updatedDate);
  }

  @action
  setDate(date) {
    const updatedDate = new Date(date);

    const currentDate = this.args.field.value || new Date();

    updatedDate.setHours(currentDate.getHours(), currentDate.getMinutes());

    this.args.field.set(updatedDate);
  }

  @action
  formatForInput(date) {
    return moment(date).format("YYYY-MM-DD");
  }

  @action
  formatTimeForInput(date) {
    console.log(moment(date).format("HH:mm"));
    return moment(date).format("HH:mm");
  }

  get minDate() {
    return this.args.field.rules?.dateAfterOrEqual?.date;
  }

  get minTime() {
    return this.args.field.rules?.dateAfterOrEqual?.time;
  }

  get maxDate() {
    return this.args.field.rules?.dateBeforeOrEqual?.date;
  }

  get expandedDatePicker() {
    return (
      (this.args.expandedDatePickerOnDesktop ?? true) && this.site.desktopView
    );
  }

  get date() {
    return this.args.field.value?.toDate();
  }

  <template>
    {{#if this.expandedDatePicker}}
      <DatePicker
        @value={{readonly @field.value}}
        @onSelect={{this.setDate}}
        @containerId={{this.containerId}}
        @minDate={{this.minDate}}
        @maxDate={{this.maxDate}}
        id={{@field.id}}
        class="form-kit__control-calendar"
      />
      <div id={{this.containerId}} class="date-picker-container"></div>
    {{else}}
      <input
        min={{this.formatForInput this.minDate}}
        max={{this.formatForInput this.maxDate}}
        disabled={{@field.disabled}}
        class="form-kit__control-input form-kit__control-date"
        type="date"
        value={{@field.value}}
        {{on "change" (withEventValue this.setDate)}}
      />
    {{/if}}

    {{#if this.includeTime}}
      {{this.time}}
      <input
        disabled={{@field.disabled}}
        type="time"
        value={{this.time}}
        {{on "input" (withEventValue this.setTime)}}
        class="form-kit__control-input form-kit__control-time"
        step="900"
        min={{this.minTime}}
      />
    {{/if}}
  </template>
}
