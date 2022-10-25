import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";

export default class extends Component {
  @tracked categoryId = this.args.value;

  @action
  onChange(category) {
    this.categoryId = category;
    this.args.categoryChanged?.(category);
  }
}
