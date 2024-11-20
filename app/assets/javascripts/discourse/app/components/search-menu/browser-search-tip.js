import Component from "@glimmer/component";
import { translateModKey } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default class BrowserSearchTip extends Component {
  get translatedLabel() {
    return i18n("search.browser_tip", { modifier: translateModKey("Meta+") });
  }
}
