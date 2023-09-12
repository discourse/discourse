import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import I18n from "I18n";

export default class UserTip extends Component {
  @service currentUser;
  @service userTips;

  willDestroy() {
    this.userTips.hideTip(this.args.id);
  }

  @action
  showUserTip(element) {
    if (!this.currentUser) {
      return;
    }

    const {
      id,
      selector,
      content,
      placement,
      buttonLabel,
      buttonIcon,
      onDismiss,
    } = this.args;
    element = element.parentElement;

    this.currentUser.showUserTip({
      id,
      titleText: I18n.t(`user_tips.${id}.title`),
      contentHtml: content,
      contentText: I18n.t(`user_tips.${id}.content`),
      buttonLabel,
      buttonIcon,
      reference:
        (selector && element.parentElement.querySelector(selector)) || element,
      appendTo: element.parentElement,
      placement,
      onDismiss,
    });
  }
}
