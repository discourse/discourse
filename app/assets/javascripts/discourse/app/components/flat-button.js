import Component from "@ember/component";
import {
  attributeBindings,
  classNames,
  tagName,
} from "@ember-decorators/component";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

@tagName("button")
@classNames("btn-flat")
@attributeBindings("disabled", "translatedTitle:title")
export default class FlatButton extends Component {
  @discourseComputed("title")
  translatedTitle(title) {
    if (title) {
      return I18n.t(title);
    }
  }

  keyDown(event) {
    if (event.key === "Enter") {
      this.action?.();
      return false;
    }
  }

  click() {
    this.action?.();
    return false;
  }
}
