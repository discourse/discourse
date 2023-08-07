import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { bind } from "discourse-common/utils/decorators";
import discourseDebounce from "discourse-common/lib/debounce";

export default class NavigationFilter extends Component {
  @tracked copyIcon = "link";
  @tracked copyClass = "btn-default";
  @tracked newQueryString = "";

  constructor() {
    super(...arguments);
    this.newQueryString = this.args.queryString;
  }

  @bind
  updateQueryString(string) {
    this.newQueryString = string;
  }

  @action
  clearInput() {
    this.newQueryString = "";
    this.args.updateTopicsListQueryParams(this.newQueryString);
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
