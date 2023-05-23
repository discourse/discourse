import Component from "@glimmer/component";

export default class extends Component {
  get prefixValue() {
    if (!this.args.prefixType && !this.args.prefixValue) {
      return;
    }

    switch (this.args.prefixType) {
      case "span":
        let hexValues = this.args.prefixValue;

        hexValues = hexValues.reduce((acc, color) => {
          if (color?.match(/^([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/)) {
            acc.push(`#${color} 50%`);
          }

          return acc;
        }, []);

        if (hexValues.length === 1) {
          hexValues.push(hexValues[0]);
        }

        return hexValues.join(", ");
        break;
      default:
        return this.args.prefixValue;
    }
  }
}
