import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";

// A click overrides the subclass's filter-derived default, remembered against
// the filter it was made under, so a new search starts from its own default.
export default class ExpandableRow extends Component {
  @tracked choice = null;
  @tracked choiceFilter = "";

  get autoExpanded() {
    return false;
  }

  get expanded() {
    if (this.choice !== null && this.choiceFilter === this.filter) {
      return this.choice;
    }
    return this.autoExpanded;
  }

  get filter() {
    return this.args.filter ?? "";
  }

  @action
  toggle() {
    this.choice = !this.expanded;
    this.choiceFilter = this.filter;
  }
}
