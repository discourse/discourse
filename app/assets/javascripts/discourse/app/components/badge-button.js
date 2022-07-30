import Component from "@ember/component";
import { computed } from "@ember/object";
import domFromString from "discourse-common/lib/dom-from-string";

export default class BadgeButtonComponent extends Component {
  tagName = "";
  badge = null;

  @computed("badge.description")
  get title() {
    if (this.badge?.description) {
      return domFromString(`<div>${this.badge?.description}</div>`)[0]
        .innerText;
    }
  }
}
