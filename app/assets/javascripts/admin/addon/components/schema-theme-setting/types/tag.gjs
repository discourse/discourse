import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import TagChooser from "select-kit/components/tag-chooser";
import { hash } from "@ember/helper";

export default class SchemaThemeSettingTypeTag extends Component {
  @tracked value;

  constructor() {
    super(...arguments);
    this.value = this.args.value;
  }

  @action
  onInput(newVal) {
    this.value = newVal;
    this.args.onChange(newVal);
  }

  <template>
    <TagChooser
      @tags={{this.value}}
      @onChange={{this.onInput}}
      @options={{hash allowAny=false}}
    />
  </template>
}
