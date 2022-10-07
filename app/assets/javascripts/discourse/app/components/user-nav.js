import I18n from "I18n";

import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { next } from "@ember/runloop";

import { bind } from "discourse-common/utils/decorators";
import { DROPDOWN_BUTTON_CSS_CLASS } from "discourse/components/user-nav/dropdown-list";

export default class UserNav extends Component {
  @service currentUser;
  @service site;
  @service router;

  get draftLabel() {
    const count = this.currentUser.draft_count;

    return count > 0
      ? I18n.t("drafts.label_with_count", { count })
      : I18n.t("drafts.label");
  }

  @bind
  _handleClickEvent(event) {
    if (!event.target.closest(`.${DROPDOWN_BUTTON_CSS_CLASS}`)) {
      next(() => {
        this.args.toggleUserNav();
      });
    }
  }

  @action
  registerClickListener(element) {
    if (this.site.mobileView) {
      element.addEventListener("click", this._handleClickEvent);
    }
  }

  @action
  unregisterClickListener(element) {
    if (this.site.mobileView) {
      element.removeEventListener("click", this._handleClickEvent);
    }
  }
}
