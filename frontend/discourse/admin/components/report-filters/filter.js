import Component from "@glimmer/component";
import { action } from "@ember/object";

export default class Filter extends Component {
  @action
  onChange(value) {
    this.args.applyFilter(this.args.filter.id, value);
  }
}
