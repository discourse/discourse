import Component from "@glimmer/component";
import I18n from "I18n";
import { translateModKey } from "discourse/lib/utilities";

export default class BrowserSearchTip extends Component {
  get translatedLabel() {
    return I18n.t("search.browser_tip", { modifier: translateModKey("Meta+") });
  }
}
