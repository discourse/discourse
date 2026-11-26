import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { adjustedRangeEnd } from "discourse/lib/time-utils";
import DDateTimeInput, {
  type DDateTimeInputDate,
} from "discourse/ui-kit/d-date-time-input";
import { i18n } from "discourse-i18n";

/** A range of dates. */
export interface DDateTimeInputRangeValue {
  from?: DDateTimeInputDate | null;
  to?: DDateTimeInputDate | null;
}

interface DDateTimeInputRangeSignature {
  Args: {
    /** The start of the range. */
    from?: DDateTimeInputDate | null;

    /** The end of the range. */
    to?: DDateTimeInputDate | null;

    /** The timezone of the range. Defaults to the timezone of the browser. */
    timezone?: string;

    /** Whether the end input shows its time before its date. Defaults to `false`. */
    toTimeFirst?: boolean;

    /** Whether the start input shows a time. Defaults to `true`. */
    showFromTime?: boolean;

    /** Whether the end input shows a time. Defaults to `true`. */
    showToTime?: boolean;

    /** Whether the end input can be cleared. Defaults to `false`. */
    clearable?: boolean;

    /** Called with the new range, with the end moved after the start when needed. */
    onChange?: (range: DDateTimeInputRangeValue) => void;
  };
  Element: HTMLDivElement;
}

export default class DDateTimeInputRange extends Component<DDateTimeInputRangeSignature> {
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
  onChangeRanges(options: { prop: string }, value: DDateTimeInputDate | null) {
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
