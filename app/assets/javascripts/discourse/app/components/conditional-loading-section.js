import Component from "@ember/component";
import { classNameBindings, classNames } from "@ember-decorators/component";
import I18n from "discourse-i18n";

@classNames("conditional-loading-section")
@classNameBindings("isLoading")
export default class ConditionalLoadingSection extends Component {
  isLoading = false;
  title = I18n.t("conditional_loading_section.loading");
}
