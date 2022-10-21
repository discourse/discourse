import Component from "@ember/component";
import { schedule } from "@ember/runloop";
import { hidePopup } from "discourse/lib/popup";
import Ember from "ember";
import I18n from "I18n";

export default class OnboardingPopup extends Component {
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
      this.currentUser.showPopup({
        id: this.id,

        titleText: I18n.t(`popup.${this.id}.title`),
        contentText: this.content || I18n.t(`popup.${this.id}.content`),

        reference: this.selector
          ? parentElement.querySelector(this.selector)
          : parentElement,

        placement: this.placement || "top",
      });
    });
  }

  willDestroyElement() {
    this._super(...arguments);

    hidePopup(this.id);
  }
}
