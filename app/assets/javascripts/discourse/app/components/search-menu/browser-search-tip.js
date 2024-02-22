import Component from "@glimmer/component";
import { translateModKey } from "discourse/lib/utilities";
import I18n from "discourse-i18n";

export default class BrowserSearchTip extends Component {
  get translatedLabel() {
    return I18n.t("search.browser_tip", { modifier: translateModKey("Meta+") });
  }
}
