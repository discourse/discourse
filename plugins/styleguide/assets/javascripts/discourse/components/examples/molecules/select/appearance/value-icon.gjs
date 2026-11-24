import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { notificationLevels } from "../../../../../lib/select-fixtures.js";

export default class ValueIconSelectExample extends Component {
  @tracked value = "tracking";

  get items() {
    return notificationLevels();
  }

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @iconField="icon"
      @identifier="sg-icon-follows"
      @labelField="title"
      @onChange={{this.onChange}}
      @options={{this.items}}
      @value={{this.value}}
      @valueField="level"
      @variant="static"
    />
  </template>
}
