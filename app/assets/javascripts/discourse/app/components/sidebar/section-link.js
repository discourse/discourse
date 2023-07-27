import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

/**
 * Checks if a given string is a valid color hex code.
 *
 * @param {String|undefined} input Input string to check if it is a valid color hex code. Can be in the form of "FFFFFF" or "#FFFFFF" or "FFF" or "#FFF".
 * @returns {String|undefined} Returns the matching color hex code without the leading `#` if it is valid, otherwise returns undefined. Example: "FFFFFF" or "FFF".
 */
export function isHex(input) {
  const match = input?.match(/^#?([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/);

  if (match) {
    return match[1];
  } else {
    return;
  }
}
export default class SectionLink extends Component {
  @service currentUser;

  willDestroy() {
    if (this.args.willDestroy) {
      this.args.willDestroy();
    }
  }

  didInsert(_element, [args]) {
    if (args.didInsert) {
      args.didInsert();
    }
  }

  get shouldDisplay() {
    if (this.args.shouldDisplay === undefined) {
      return true;
    }

    return this.args.shouldDisplay;
  }

  get classNames() {
    let classNames = ["sidebar-section-link", "sidebar-row"];

    if (this.args.class) {
      classNames.push(this.args.class);
    }

    return classNames.join(" ");
  }

  get target() {
    if (this.args.fullReload) {
      return "_self";
    }
    return this.currentUser?.user_option?.external_links_in_new_tab
      ? "_blank"
      : "_self";
  }

  get models() {
    if (this.args.model) {
      return [this.args.model];
    }

    if (this.args.models) {
      return this.args.models;
    }

    return [];
  }

  get prefixColor() {
    const hexCode = isHex(this.args.prefixColor);

    if (hexCode) {
      return `#${hexCode}`;
    } else {
      return;
    }
  }
}
