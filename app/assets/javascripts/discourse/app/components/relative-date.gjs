import Component from "@glimmer/component";
import { longDate, relativeAge } from "discourse/lib/formatter";

export default class RelativeDate extends Component {
  get datetime() {
    return new Date(this.args.date);
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
