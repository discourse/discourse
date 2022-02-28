import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";

export default class BaseField extends Component {
  tagName = "";
  placeholders = null;
  field = null;
  saveAutomation = null;

  @discourseComputed("placeholders.length", "field.acceptsPlaceholders")
  displayPlaceholders(hasPlaceholders, acceptsPlaceholders) {
    return hasPlaceholders && acceptsPlaceholders;
  }
}
