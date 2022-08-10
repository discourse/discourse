import Component from "@glimmer/component";
import domFromString from "discourse-common/lib/dom-from-string";

// Takes @badge as argument.
export default class BadgeButtonComponent extends Component {
  get title() {
    const description = this.args.badge?.description;
    if (description) {
      return domFromString(`<div>${description}</div>`)[0].innerText;
    }
  }
}
