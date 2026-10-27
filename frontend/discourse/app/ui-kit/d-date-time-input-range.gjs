import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { adjustedRangeEnd } from "discourse/lib/time-utils";
import DDateTimeInput from "discourse/ui-kit/d-date-time-input";
import { i18n } from "discourse-i18n";

export default class DDateTimeInputRange extends Component {
  get toTimeFirst() {
    return this.args.toTimeFirst ?? false;
  }

  get showToTime() {
    return this.args.showToTime ?? true;
  }

  get showFromTime() {
    return this.args.showFromTime ?? true;
  }

  get clearable() {
    return this.args.clearable ?? false;
  }

  @action
  onChangeRanges(options, value) {
    if (!this.args.onChange) {
      return;
    }

    const from = options.prop === "from" ? value : this.args.from;
    const to = options.prop === "from" ? this.args.to : value;

    this.args.onChange({
      from,
      to: adjustedRangeEnd(from, to, { dateOnly: !this.showToTime }),
    });
  }

  <template>
    <div class="d-date-time-input-range" ...attributes>
      <DDateTimeInput
        class="from"
        @date={{@from}}
        @onChange={{fn this.onChangeRanges (hash prop="from")}}
        @placeholder={{i18n "dates.from_placeholder"}}
        @showTime={{this.showFromTime}}
        @timezone={{@timezone}}
      />

      <DDateTimeInput
        class="to"
        @clearable={{this.clearable}}
        @date={{@to}}
        @onChange={{fn this.onChangeRanges (hash prop="to")}}
        @placeholder={{i18n "dates.to_placeholder"}}
        @relativeDate={{@from}}
        @showTime={{this.showToTime}}
        @timeFirst={{this.toTimeFirst}}
        @timezone={{@timezone}}
      />
    </div>
  </template>
}
