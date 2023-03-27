import Component from "@glimmer/component";
import I18n from "I18n";
import { translateModKey } from "discourse/lib/utilities";

export default class ComposerSaveButton extends Component {
  get translatedTitle() {
    return I18n.t("composer.title", { modifier: translateModKey("Meta+") });
  }
}
