import Component from "@glimmer/component";

export default class SectionLink extends Component {
  willDestroy() {
    if (this.args.willDestroy) {
      this.args.willDestroy();
    }
  }

  get shouldDisplay() {
    if (this.args.shouldDisplay === undefined) {
      return true;
    }

    return this.args.shouldDisplay;
  }

  get classNames() {
    let classNames = [
      "sidebar-section-link",
      `sidebar-section-link-${this.args.linkName}`,
      "sidebar-row",
    ];

    if (this.args.class) {
      classNames.push(this.args.class);
    }

    return classNames.join(" ");
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
    const prefixElementColors = this.args.prefixElementColors.filter((color) =>
      color?.match(/^\w{6}$/)
    );
    if (prefixElementColors.length === 1) {
      prefixElementColors.push(prefixElementColors[0]);
    }
    return prefixElementColors.map((color) => `#${color} 50%`).join(", ");
  }
}
