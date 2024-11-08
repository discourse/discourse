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
@attributeBindings("disabled", "resolvedTitle:title")
export default class FlatButton extends Component {
  @discourseComputed("title", "translatedTitle")
  resolvedTitle(title, translatedTitle) {
    if (title) {
      return I18n.t(title);
    } else if (translatedTitle) {
      return translatedTitle;
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
