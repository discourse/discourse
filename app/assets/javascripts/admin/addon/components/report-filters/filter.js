import Component from "@ember/component";
import { action } from "@ember/object";

export default class Filter extends Component {
  // DELETE THIS COMMENT: referenced by group.js
  // DELETE THIS COMMENT: referenced by list.js
  @__action__
  onChange(value) {
    this.applyFilter(this.filter.id, value);
  }
}
