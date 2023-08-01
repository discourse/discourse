import Controller, { inject as controller } from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { bind } from "discourse-common/utils/decorators";
import discourseDebounce from "discourse-common/lib/debounce";

export default class extends Controller {
  @controller("discovery/filter") discoveryFilter;

  @tracked copyIcon = "link";
  @tracked copyClass = "btn-default";
  @tracked newQueryString = "";

  constructor() {
    super(...arguments);
    this.newQueryString = this.discoveryFilter.q;
  }

  @action
  clearInput() {
    this.newQueryString = "";
    this.discoveryFilter.updateTopicsListQueryParams(this.newQueryString);
  }

  @action
  copyQueryString() {
    // hacky way to copy to clipboard
    // that also works in development enviro
    let temp = document.createElement("textarea");
    temp.value = window.location;
    document.body.appendChild(temp);
    temp.select();
    document.execCommand("copy");
    document.body.removeChild(temp);

    this.copyIcon = "check";
    this.copyClass = "btn-default ok";

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
