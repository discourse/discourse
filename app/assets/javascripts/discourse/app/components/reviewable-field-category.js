import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";

export default class extends Component {
  @tracked categoryId = this.args.value;

  @action
  onChange(category) {
    this.categoryId = category;
    this.args.categoryChanged?.(category);
  }
}
