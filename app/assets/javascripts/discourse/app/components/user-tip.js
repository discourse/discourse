import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { inject as service } from "@ember/service";
import Component from "@glimmer/component";
import { hideUserTip } from "discourse/lib/user-tips";
import I18n from "I18n";

export default class UserTip extends Component {
  @service currentUser;

  @action
  showUserTip(element) {
    if (!this.currentUser) {
      return;
    }

    schedule("afterRender", () => {
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
        contentText: content || I18n.t(`user_tips.${id}.content`),
        buttonLabel,
        buttonIcon,
        reference:
          (selector && element.parentElement.querySelector(selector)) ||
          element,
        appendTo: element.parentElement,
        placement,
        onDismiss,
      });
    });
  }

  willDestroy() {
    hideUserTip(this.args.id);
  }
}
