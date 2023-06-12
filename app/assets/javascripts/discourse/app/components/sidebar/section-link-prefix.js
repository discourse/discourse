import Component from "@glimmer/component";
import { isHex } from "discourse/components/sidebar/section-link";

export default class extends Component {
  get prefixValue() {
    if (!this.args.prefixType && !this.args.prefixValue) {
      return;
    }

    switch (this.args.prefixType) {
      case "span":
        let hexValues = this.args.prefixValue;

        hexValues = hexValues.reduce((acc, color) => {
          const hexCode = isHex(color);

          if (hexCode) {
            acc.push(`#${hexCode} 50%`);
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
