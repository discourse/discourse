import Component from "@glimmer/component";
import { action } from "@ember/object";

export default class BaseField extends Component {
  get displayPlaceholders() {
    return (
      this.args.placeholders?.length && this.args.field?.acceptsPlaceholders
    );
  }

  @action
  mutValue(newValue) {
    this.args.field.metadata.value = newValue;
  }
}
