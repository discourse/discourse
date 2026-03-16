import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSegmentedControl from "discourse/components/d-segmented-control";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class SegmentedControl extends Component {
  @tracked value1 = "week";

  items1 = [
    { value: "day", label: "Day" },
    { value: "week", label: "Week" },
    { value: "month", label: "Month" },
    { value: "year", label: "Year" },
    { value: "all", label: "All" },
  ];

  get basicCode() {
    return `import DSegmentedControl from "discourse/components/d-segmented-control";

<template>
  <DSegmentedControl
    @name="time-period"
    @items={{this.items}}
    @value={{this.selected}}
    @onSelect={{this.handleSelect}}
  />
</template>`;
  }

  @action
  onSelect1(value) {
    this.value1 = value;
  }

  <template>
    <StyleguideExample @title="<DSegmentedControl>" @code={{this.basicCode}}>
      <DSegmentedControl
        @name="time-period"
        @items={{this.items1}}
        @value={{this.value1}}
        @onSelect={{this.onSelect1}}
      />
    </StyleguideExample>
  </template>
}
