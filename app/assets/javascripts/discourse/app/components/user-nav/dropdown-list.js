import GlimmerComponent from "discourse/components/glimmer";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { bind } from "discourse-common/utils/decorators";

export default class UserNavDropdownList extends GlimmerComponent {
  @tracked displayList = false;

  get chevron() {
    return this.displayList ? "chevron-up" : "chevron-down";
  }

  @action
  toggleList() {
    this.displayList = !this.displayList;
  }

  @bind
  collapseList(e) {
    const isClickOnButton = e.composedPath().some((element) => {
      if (element?.classList?.contains("user-primary-navigation_item-button")) {
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
