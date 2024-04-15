import Component from "@glimmer/component";
import { translateModKey } from "discourse/lib/utilities";
import I18n from "discourse-i18n";

export default class ComposerSaveButton extends Component {
  get translatedTitle() {
    return I18n.t("composer.title", { modifier: translateModKey("Meta+") });
  }
}
