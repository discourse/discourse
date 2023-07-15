import { inject as controller } from "@ember/controller";
import Component from "@glimmer/component";

export default class extends Component {
  constructor() {
    super(...arguments);
    this.queryString = this.args.queryString;
  }
}
