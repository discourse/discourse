import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import MiniTagChooser from "discourse/select-kit/components/mini-tag-chooser";

export default class MiniTagChooserExample extends Component {
  @tracked tags = ["apple", "orange", "potato"];

  @action
  onChange(tags) {
    this.tags = tags;
  }

  <template>
    <MiniTagChooser
      @onChange={{this.onChange}}
      @options={{hash filterable=true}}
      @value={{this.tags}}
    />
  </template>
}
