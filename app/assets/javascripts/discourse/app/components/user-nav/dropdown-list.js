import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { bind } from "discourse-common/utils/decorators";

export default class UserNavDropdownList extends Component {
  @tracked displayList = false;

  get chevron() {
    return this.displayList ? "chevron-up" : "chevron-down";
  }

  get defaultButtonClass() {
    return "user-nav-dropdown-button";
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
