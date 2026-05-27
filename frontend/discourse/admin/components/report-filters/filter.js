/* eslint-disable ember/no-classic-components, ember/require-tagless-components */
import Component from "@ember/component";
import { action } from "@ember/object";

export default class Filter extends Component {
  @action
  onChange(value) {
    this.applyFilter(this.filter.id, value);
  }
}
