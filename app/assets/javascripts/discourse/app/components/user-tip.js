import Component from "@ember/component";
import { schedule } from "@ember/runloop";
import { hideUserTip } from "discourse/lib/user-tips";
import Ember from "ember";
import I18n from "I18n";

export default class UserTip extends Component {
  tagName = "";

  id = null;
  placement = null;
  selector = null;

  didInsertElement() {
    this._super(...arguments);

    if (!this.currentUser) {
      return;
    }

    schedule("afterRender", () => {
      const parentElement = Ember.ViewUtils.getViewBounds(this).parentElement;
      this.currentUser.showUserTip({
        id: this.id,

        titleText: I18n.t(`user_tips.${this.id}.title`),
        contentText: this.content || I18n.t(`user_tips.${this.id}.content`),

        reference: this.selector
          ? parentElement.querySelector(this.selector)
          : parentElement,

        placement: this.placement || "top",
      });
    });
  }

  willDestroyElement() {
    this._super(...arguments);

    hideUserTip(this.id);
  }
}
