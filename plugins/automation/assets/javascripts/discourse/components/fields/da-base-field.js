import Component from "@ember/component";
import { computed } from "@ember/object";

export default class BaseField extends Component {
  tagName = "";
  placeholders = null;
  field = null;
  saveAutomation = null;

  @computed("placeholders.length", "field.acceptsPlaceholders")
  get displayPlaceholders() {
    return this.placeholders?.length && this.field?.acceptsPlaceholders;
  }
}
