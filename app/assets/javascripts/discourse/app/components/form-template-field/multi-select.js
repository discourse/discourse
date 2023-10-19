import Component from "@glimmer/component";
import { action } from "@ember/object";

export default class FormTemplateFieldMultiSelect extends Component {
  @action
  isSelected(option) {
    return this.args.value?.includes(option);
  }
}
