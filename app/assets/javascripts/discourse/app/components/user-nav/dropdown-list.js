import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";

import { bind } from "discourse-common/utils/decorators";

export const DROPDOWN_BUTTON_CSS_CLASS = "user-nav-dropdown-button";
export default class UserNavDropdownList extends Component {
  @service site;
  @tracked displayList = this.site.mobileView && this.args.isActive;

  get chevron() {
    return this.displayList ? "chevron-up" : "chevron-down";
  }

  get defaultButtonClass() {
    return DROPDOWN_BUTTON_CSS_CLASS;
  }

  get buttonClass() {
    const props = [this.defaultButtonClass];

    if (this.args.isActive) {
      props.push("active");
    }

    return props.join(" ");
  }

  @action
  toggleList() {
    this.displayList = !this.displayList;
  }

  @bind
  collapseList(e) {
    const isClickOnButton = e.composedPath().some((element) => {
      if (element?.classList?.contains(this.defaultButtonClass)) {
        return true;
      }
    });

    if (!isClickOnButton) {
      this.displayList = false;
    }
  }

  @action
  registerClickListener() {
    document.addEventListener("click", this.collapseList);
  }

  @action
  deregisterClickListener() {
    document.removeEventListener("click", this.collapseList);
  }
}
