import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

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
    const color = this.args.prefixColor;

    if (!color || !color.match(/^\w{6}$/)) {
      return "";
    }

    return "#" + color;
  }

  get prefixElementColors() {
    if (!this.args.prefixElementColors) {
      return;
    }

    const prefixElementColors = this.args.prefixElementColors.filter((color) =>
      color?.slice(0, 6)
    );

    if (prefixElementColors.length === 1) {
      prefixElementColors.push(prefixElementColors[0]);
    }

    return prefixElementColors.map((color) => `#${color} 50%`).join(", ");
  }
}
