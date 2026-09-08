import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import FKBaseControl from "discourse/form-kit/components/fk/control/base";
import withEventValue from "discourse/helpers/with-event-value";
import DDatePicker from "discourse/ui-kit/d-date-picker";

export default class FKControlCalendar extends FKBaseControl {
  static controlType = "calendar";

  @service site;

  get containerId() {
    return `${this.args.field.name}-container`;
  }

  get time() {
    return this.args.field.value
      ? moment(this.args.field.value).format("HH:mm")
      : null;
  }

  get includeTime() {
    return this.args.includeTime ?? true;
  }

  get minDate() {
    return this.args.field.rules?.dateAfterOrEqual?.date;
  }

  get maxDate() {
    return this.args.field.rules?.dateBeforeOrEqual?.date;
  }

  get expandedDatePicker() {
    return (
      (this.args.expandedDatePickerOnDesktop ?? true) && this.site.desktopView
    );
  }

  @action
  setTime(time) {
    const [hours, minutes] = time.split(":").map(Number);
    const updatedDate = new Date(this.args.field.value.getTime());
    updatedDate.setHours(hours, minutes, 0, 0);
    this.args.field.set(updatedDate);
  }

  @action
  setDate(date) {
    let [year, month, day] = date.split("-").map(Number);
    month -= 1;

    const updatedDate = new Date(year, month, day);
    const currentDate = this.args.field.value || new Date();

    updatedDate.setHours(
      currentDate.getHours(),
      currentDate.getMinutes(),
      0,
      0
    );

    this.args.field.set(updatedDate);
  }

  @action
  formatForInput(date) {
    return moment(date).format("YYYY-MM-DD");
  }

  <template>
    {{#if this.expandedDatePicker}}
      <DDatePicker
        aria-describedby={{@field.describedBy}}
        aria-invalid={{if @field.error "true"}}
        class="form-kit__control-calendar"
        id={{@field.id}}
        name={{@field.name}}
        @containerId={{this.containerId}}
        @maxDate={{this.maxDate}}
        @minDate={{this.minDate}}
        @onSelect={{this.setDate}}
        @value={{readonly @field.value}}
      />
      <div class="date-picker-container" id={{this.containerId}}></div>
    {{else}}
      <input
        aria-describedby={{@field.describedBy}}
        class="form-kit__control-input form-kit__control-date"
        disabled={{@field.disabled}}
        id={{@field.id}}
        max={{this.formatForInput this.maxDate}}
        min={{this.formatForInput this.minDate}}
        name={{@field.name}}
        type="date"
        value={{this.date}}
        {{on "change" (withEventValue this.setDate)}}
      />
    {{/if}}

    {{#if this.includeTime}}
      <input
        class="form-kit__control-input form-kit__control-time"
        disabled={{@field.disabled}}
        step="900"
        type="time"
        value={{this.time}}
        {{on "input" (withEventValue this.setTime)}}
      />
    {{/if}}
  </template>
}
