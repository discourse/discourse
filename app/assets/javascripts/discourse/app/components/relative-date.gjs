import Component from "@glimmer/component";
import { longDate, relativeAge } from "discourse/lib/formatter";

export default class RelativeDate extends Component {
  get datetime() {
    if (this.memoizedDatetime) {
      return this.memoizedDatetime;
    }

    this.memoizedDatetime = new Date(this.args.data.date);
    return this.memoizedDatetime;
  }

  get title() {
    return longDate(this.datetime);
  }

  get time() {
    return this.datetime.getTime();
  }

  <template>
    <span
      class="relative-date"
      title={{this.title}}
      data-time={{this.time}}
      data-format="tiny"
    >
      {{relativeAge this.datetime}}
    </span>
  </template>
}
