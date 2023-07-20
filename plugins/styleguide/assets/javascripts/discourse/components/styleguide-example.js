import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";

export default class StyleguideExample extends Component {
  @tracked value = null;

  constructor() {
    super(...arguments);
    this.value = this.args.initialValue;
  }
}
