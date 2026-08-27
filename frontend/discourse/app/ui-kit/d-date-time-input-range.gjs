/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import { adjustedRangeEnd } from "discourse/lib/time-utils";
import DDateTimeInput from "discourse/ui-kit/d-date-time-input";
import { i18n } from "discourse-i18n";

@tagName("")
export default class DDateTimeInputRange extends Component {
  from = null;
  to = null;
  toTimeFirst = false;
  showToTime = true;
  showFromTime = true;
  clearable = false;

  @action
  onChangeRanges(options, value) {
    if (!this.onChange) {
      return;
    }

    const from = options.prop === "from" ? value : this.from;
    const to = options.prop === "from" ? this.to : value;

    this.onChange({
      from,
      to: adjustedRangeEnd(from, to, { dateOnly: !this.showToTime }),
    });
  }

  <template>
    <div class="d-date-time-input-range" ...attributes>
      <DDateTimeInput
        @date={{this.from}}
        @onChange={{fn this.onChangeRanges (hash prop="from")}}
        @showTime={{this.showFromTime}}
        @placeholder={{i18n "dates.from_placeholder"}}
        @timezone={{@timezone}}
        class="from"
      />

      <DDateTimeInput
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
    </div>
  </template>
}
