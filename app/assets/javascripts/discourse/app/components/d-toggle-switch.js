import Component from "@glimmer/component";
import I18n from "I18n";

export default class DToggleSwitch extends Component {
  get computedLabel() {
    if (this.args.label) {
      return I18n.t(this.args.label);
    }
    return this.args.translatedLabel;
  }

  get checked() {
    return this.args.state ? "true" : "false";
  }
}
