import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import domFromString from "discourse-common/lib/dom-from-string";

export default class BadgeButtonComponent extends Component {
  tagName = "";
  badge = null;

  @discourseComputed("badge.description")
  title(badgeDescription) {
    return domFromString(`<div>${badgeDescription}</div>`)[0].innerText;
  }
}
