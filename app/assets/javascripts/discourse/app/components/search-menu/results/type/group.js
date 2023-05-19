import Component from "@glimmer/component";
import { escapeExpression } from "discourse/lib/utilities";

export default class Group extends Component {
  get fullName() {
    return escapeExpression(this.args.result.fullName);
  }

  get name() {
    return escapeExpression(this.args.result.name);
  }
}
