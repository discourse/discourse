import Component from "@ember/component";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import DateTimeInput from "discourse/components/date-time-input";
import { i18n } from "discourse-i18n";

@classNames("d-date-time-input-range")
export default class DateTimeInputRange extends Component {
  from = null;
  to = null;
  onChangeTo = null;
  onChangeFrom = null;
  toTimeFirst = false;
  showToTime = true;
  showFromTime = true;
  clearable = false;

  @action
  onChangeRanges(options, value) {
    if (this.onChange) {
      const state = {
        from: this.from,
        to: this.to,
      };

      const diff = {};

      if (options.prop === "from") {
        if (this.to && value?.isAfter(this.to)) {
          diff[options.prop] = value;
          diff["to"] = value.clone().add(1, "hour");
        } else {
          diff[options.prop] = value;
        }
      }

      if (options.prop === "to") {
        if (value && value.isBefore(this.from)) {
          diff[options.prop] = this.from.clone().add(1, "hour");
        } else {
          diff[options.prop] = value;
        }
      }

      const newState = { ...state, ...diff };
      this.onChange(newState);
    }
  }

  <template>
    <DateTimeInput
      @date={{this.from}}
      @onChange={{fn this.onChangeRanges (hash prop="from")}}
      @showTime={{this.showFromTime}}
      @placeholder={{i18n "dates.from_placeholder"}}
      @timezone={{@timezone}}
      class="from"
    />

    <DateTimeInput
      @date={{this.to}}
      @relativeDate={{this.from}}
      @onChange={{fn this.onChangeRanges (hash prop="to")}}
      @timeFirst={{this.toTimeFirst}}
      @showTime={{this.showToTime}}
      @clearable={{this.clearable}}
      @placeholder={{i18n "dates.to_placeholder"}}
      @timezone={{@timezone}}
      class="to"
    />
  </template>
}
