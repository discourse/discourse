import Component from "@glimmer/component";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import DDateInput from "discourse/ui-kit/d-date-input";
import DTimeInput from "discourse/ui-kit/d-time-input";

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

  get resolvedTimezone() {
    return this.args.timezone || moment.tz.guess();
  }

  @action
  onClear() {
    this.args.onChange(null);
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
        moment.tz(
          {
            year: date.year(),
            month: date.month(),
            day: date.date(),
            hours: time.hours,
            minutes: time.minutes,
          },
          this.resolvedTimezone
        )
      );
    }
  }

  @action
  onChangeDate(date) {
    if (!date) {
      this.onClear();
      return;
    }

    this.args.onChange?.(
      moment.tz(
        {
          year: date.year(),
          month: date.month(),
          day: date.date(),
          hours: this.hours || 0,
          minutes: this.minutes || 0,
        },
        this.resolvedTimezone
      )
    );
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
        <DTimeInput
          @date={{this.date}}
          @onChange={{this.onChangeTime}}
          @relativeDate={{this.relativeDate}}
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
