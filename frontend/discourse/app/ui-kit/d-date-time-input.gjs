/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { action, computed } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import DButton from "discourse/ui-kit/d-button";
import DDateInput from "discourse/ui-kit/d-date-input";
import DTimeInput from "discourse/ui-kit/d-time-input";

@tagName("")
export default class DDateTimeInput extends Component {
  date = null;
  relativeDate = null;
  showTime = true;
  clearable = false;

  @computed("date", "showTime")
  get hours() {
    return this.date && this.get("showTime") ? this.date.hours() : null;
  }

  @computed("date", "showTime")
  get minutes() {
    return this.date && this.get("showTime") ? this.date.minutes() : null;
  }

  @action
  onClear() {
    this.onChange(null);
  }

  @action
  onChangeTime(time) {
    if (this.onChange) {
      const date = this.date
        ? this.date
        : this.relativeDate
          ? this.relativeDate
          : moment.tz(this.resolvedTimezone);

      this.onChange(
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

    this.onChange?.(
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

  @computed("timezone")
  get resolvedTimezone() {
    return this.timezone || moment.tz.guess();
  }

  <template>
    <div class="d-date-time-input" ...attributes>
      {{#unless this.timeFirst}}
        <DDateInput
          @date={{this.date}}
          @placeholder={{this.placeholder}}
          @relativeDate={{this.relativeDate}}
          @onChange={{this.onChangeDate}}
          @useGlobalPickerContainer={{this.useGlobalPickerContainer}}
        />
      {{/unless}}

      {{#if this.showTime}}
        <DTimeInput
          @date={{this.date}}
          @relativeDate={{this.relativeDate}}
          @onChange={{this.onChangeTime}}
        />
      {{/if}}

      {{#if this.timeFirst}}
        <DDateInput
          @date={{this.date}}
          @placeholder={{this.placeholder}}
          @relativeDate={{this.relativeDate}}
          @onChange={{this.onChangeDate}}
          @useGlobalPickerContainer={{this.useGlobalPickerContainer}}
        />
      {{/if}}

      {{#if this.clearable}}
        <DButton
          @icon="xmark"
          @action={{this.onClear}}
          class="btn-default clear-date-time"
        />
      {{/if}}
    </div>
  </template>
}
