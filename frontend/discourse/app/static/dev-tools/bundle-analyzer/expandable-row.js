import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";

// A row whose open state has two sources: a default derived from the current
// filter (`autoExpanded`, supplied by the subclass) and the reader's own click.
// A click wins over the default, and is remembered against the filter it was
// made under, so it holds for as long as that search does and a different
// search starts from its own default again.
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
