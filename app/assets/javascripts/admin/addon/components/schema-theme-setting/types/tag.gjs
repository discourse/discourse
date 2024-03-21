import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import FieldInputDescription from "admin/components/schema-theme-setting/field-input-description";
import TagChooser from "select-kit/components/tag-chooser";

export default class SchemaThemeSettingTypeTag extends Component {
  @tracked value = this.args.value;

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

    <FieldInputDescription @description={{@description}} />
  </template>
}
