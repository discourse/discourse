import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSegmentedControl from "discourse/components/d-segmented-control";

const ITEMS = [
  { value: "day", label: "Day" },
  { value: "week", label: "Week" },
  { value: "month", label: "Month" },
  { value: "year", label: "Year" },
  { value: "all", label: "All" },
];

export default class SegmentedControlExample extends Component {
  @tracked selected = "week";

  @action
  onSelect(value) {
    this.selected = value;
  }

  <template>
    <DSegmentedControl
      @items={{ITEMS}}
      @name="time-period"
      @onSelect={{this.onSelect}}
      @value={{this.selected}}
    />
  </template>
}
