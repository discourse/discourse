import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import I18n from "I18n";

export default class DiscourseToggleSwitch extends Component {
  @tracked iconEnabled = true;
  @tracked showIcon = this.iconEnabled && this.icon;

  get computedLabel() {
    if (this.args.label) {
      return I18n.t(this.args.label);
    }
    return this.args.translatedLabel;
  }
}
