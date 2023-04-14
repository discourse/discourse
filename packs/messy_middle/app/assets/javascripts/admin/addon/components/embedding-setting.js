import { classNames } from "@ember-decorators/component";
import { computed } from "@ember/object";
import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import { dasherize } from "@ember/string";

@classNames("embed-setting")
export default class EmbeddingSetting extends Component {
  @discourseComputed("field")
  inputId(field) {
    return dasherize(field);
  }

  @discourseComputed("field")
  translationKey(field) {
    return `admin.embedding.${field}`;
  }

  @discourseComputed("type")
  isCheckbox(type) {
    return type === "checkbox";
  }

  @computed("value")
  get checked() {
    return !!this.value;
  }

  set(value) {
    this.set("value", value);
    return value;
  }
}
