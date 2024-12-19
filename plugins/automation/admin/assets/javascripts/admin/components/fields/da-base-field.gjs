import Component from "@glimmer/component";
import { action } from "@ember/object";

export default class BaseField extends Component {
  constructor() {
    super(...arguments);

    if (
      this.args.field.extra &&
      Object.keys(this.args.field.extra).includes("default_value")
    ) {
      this.args.field.metadata.value = this.args.field.extra.default_value;
    }
  }

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
