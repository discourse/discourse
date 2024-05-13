import Component from "@glimmer/component";
import Col from "./col";

export default class LabelWrapper extends Component {
  get size() {
    return this.args.node.context.horizontal ? 2 : this.args.node.context.size;
  }

  <template>
    <Col @node={{@node}} @size={{this.size}}>
      {{yield}}
    </Col>
  </template>
}
