import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import withEventValue from "discourse/helpers/with-event-value";
import DButton from "discourse/ui-kit/d-button";
import DDateInput from "discourse/ui-kit/d-date-input";

export default class DDateTimeInput extends Component {
  // Subclasses read the inputs by name (`this.date`), so they stay getters.
  get date() {
    return this.args.date;
  }

  get relativeDate() {
    return this.args.relativeDate;
  }

  get showTime() {
    return this.args.showTime ?? true;
  }

  get clearable() {
    return this.args.clearable ?? false;
  }

  get hours() {
    return this.date && this.showTime ? this.date.hours() : null;
  }

  get minutes() {
    return this.date && this.showTime ? this.date.minutes() : null;
  }

  get time() {
    return this.date && this.showTime ? this.date.format("HH:mm") : null;
  }

  get resolvedTimezone() {
    return this.args.timezone || moment.tz.guess();
  }

  @action
  onClear() {
    this.args.onChange?.(null);
  }

  @action
  onChangeTime(time) {
    if (this.args.onChange) {
      const date = this.date
        ? this.date
        : this.relativeDate
          ? this.relativeDate
          : moment.tz(this.resolvedTimezone);

      this.args.onChange(
        this.#atWallTime({
          year: date.year(),
          month: date.month(),
          day: date.date(),
          hours: time.hours,
          minutes: time.minutes,
        })
      );
    }
  }

  /** Reads the time input's "HH:mm"; an emptied input keeps the date's time. */
  @action
  onInputTime(value) {
    if (!value) {
      return;
    }
    const [hours, minutes] = value.split(":").map(Number);
    this.onChangeTime({ hours, minutes });
  }

  @action
  onChangeDate(date) {
    if (!date) {
      this.onClear();
      return;
    }

    this.args.onChange?.(
      this.#atWallTime({
        year: date.year(),
        month: date.month(),
        day: date.date(),
        hours: this.hours || 0,
        minutes: this.minutes || 0,
      })
    );
  }

  /**
   * Without an explicit zone, use the browser's own rules. The bundled tz data
   * only covers years near the present and gets DST offsets wrong outside them.
   */
  #atWallTime(fields) {
    return this.args.timezone
      ? moment.tz(fields, this.args.timezone)
      : moment(fields);
  }

  <template>
    <div class="d-date-time-input" ...attributes>
      {{#unless @timeFirst}}
        <DDateInput
          @date={{this.date}}
          @onChange={{this.onChangeDate}}
          @placeholder={{@placeholder}}
          @relativeDate={{this.relativeDate}}
          @useGlobalPickerContainer={{@useGlobalPickerContainer}}
        />
      {{/unless}}

      {{#if this.showTime}}
        <input
          class="time-input"
          type="time"
          value={{this.time}}
          {{on "input" (withEventValue this.onInputTime)}}
        />
      {{/if}}

      {{#if @timeFirst}}
        <DDateInput
          @date={{this.date}}
          @onChange={{this.onChangeDate}}
          @placeholder={{@placeholder}}
          @relativeDate={{this.relativeDate}}
          @useGlobalPickerContainer={{@useGlobalPickerContainer}}
        />
      {{/if}}

      {{#if this.clearable}}
        <DButton
          class="btn-default clear-date-time"
          @action={{this.onClear}}
          @icon="xmark"
        />
      {{/if}}
    </div>
  </template>
}
