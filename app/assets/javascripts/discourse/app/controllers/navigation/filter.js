import { tracked } from "@glimmer/tracking";
import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import discourseDebounce from "discourse-common/lib/debounce";
import { bind } from "discourse-common/utils/decorators";

export default class NavigationFilterController extends Controller {
  @controller("discovery/filter") discoveryFilter;

  @tracked copyIcon = "link";
  @tracked copyClass = "btn-default";
  @tracked newQueryString = "";

  @bind
  updateQueryString(string) {
    this.newQueryString = string;
  }

  @action
  clearInput() {
    this.newQueryString = "";
    this.discoveryFilter.updateTopicsListQueryParams(this.newQueryString);
  }

  @action
  copyQueryString() {
    this.copyIcon = "check";
    this.copyClass = "btn-default ok";

    navigator.clipboard.writeText(window.location);

    discourseDebounce(this._restoreButton, 3000);
  }

  @bind
  _restoreButton() {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }
    this.copyIcon = "link";
    this.copyClass = "btn-default";
  }
}
